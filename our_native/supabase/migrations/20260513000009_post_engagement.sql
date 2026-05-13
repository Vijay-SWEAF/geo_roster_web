-- ============================================================
-- Migration 009: Post engagement — cached counts + RPC helpers
-- ============================================================
-- Adds two cached columns to posts so every feed query is O(1):
--   reaction_counts  jsonb  e.g. {"respect":3,"prayers":1}
--   comment_count    int
-- Triggers keep them in sync. Two RPC helpers let the app
-- toggle a reaction and fetch the current user's own reactions.
-- ============================================================

-- 1. Add cached columns ----------------------------------------

alter table public.posts
  add column if not exists reaction_counts jsonb not null default '{}',
  add column if not exists comment_count   int  not null default 0;

-- 2. Helper: refresh reaction_counts for ONE post --------------

create or replace function public.refresh_reaction_counts_for_post(p_post_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.posts
  set reaction_counts = coalesce(
    (select jsonb_object_agg(reaction_type, cnt)
     from (
       select reaction_type, count(*) as cnt
       from public.reactions
       where post_id = p_post_id
       group by reaction_type
     ) sub),
    '{}'::jsonb
  )
  where id = p_post_id;
end;
$$;

-- 3. Trigger: reactions → refresh reaction_counts -------------

create or replace function public.trg_reactions_update_post_counts()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.refresh_reaction_counts_for_post(
    coalesce(new.post_id, old.post_id)
  );
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_reaction_counts on public.reactions;
create trigger trg_reaction_counts
  after insert or update or delete on public.reactions
  for each row execute function public.trg_reactions_update_post_counts();

-- 4. Helper: refresh comment_count for ONE post ---------------

create or replace function public.refresh_comment_count_for_post(p_post_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.posts
  set comment_count = (
    select count(*)
    from public.comments
    where post_id = p_post_id
      and status = 'approved'
  )
  where id = p_post_id;
end;
$$;

-- 5. Trigger: comments → refresh comment_count ----------------

create or replace function public.trg_comments_update_post_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.refresh_comment_count_for_post(
    coalesce(new.post_id, old.post_id)
  );
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_comment_count on public.comments;
create trigger trg_comment_count
  after insert or update of status or delete on public.comments
  for each row execute function public.trg_comments_update_post_count();

-- 6. RPC: toggle_reaction -------------------------------------
-- Single call: inserts reaction, updates type if already exists,
-- or deletes it if same type (toggle off).

create or replace function public.toggle_reaction(
  p_post_id      uuid,
  p_reaction_type text
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id        uuid := public.current_profile_id();
  v_existing_type  text;
  v_result         text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select reaction_type into v_existing_type
  from public.reactions
  where post_id = p_post_id and user_id = v_user_id;

  if found then
    if v_existing_type = p_reaction_type then
      -- Same reaction → remove (toggle off)
      delete from public.reactions
      where post_id = p_post_id and user_id = v_user_id;
      v_result := 'removed';
    else
      -- Different reaction → swap
      update public.reactions
        set reaction_type = p_reaction_type
      where post_id = p_post_id and user_id = v_user_id;
      v_result := 'swapped';
    end if;
  else
    insert into public.reactions(post_id, user_id, reaction_type)
    values (p_post_id, v_user_id, p_reaction_type);
    v_result := 'added';
  end if;

  -- Return updated counts so client can update UI without refetch
  return (
    select coalesce(jsonb_object_agg(reaction_type, cnt), '{}'::jsonb)
    from (
      select reaction_type, count(*) as cnt
      from public.reactions
      where post_id = p_post_id
      group by reaction_type
    ) sub
  );
end;
$$;

-- 7. RPC: get_my_reactions (for a list of post IDs) -----------
-- Returns {post_id: reaction_type} map for the current user.

create or replace function public.get_my_reactions(p_post_ids uuid[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id uuid := public.current_profile_id();
begin
  if v_user_id is null then
    return '{}'::jsonb;
  end if;

  return coalesce(
    (select jsonb_object_agg(post_id::text, reaction_type)
     from public.reactions
     where user_id = v_user_id
       and post_id = any(p_post_ids)),
    '{}'::jsonb
  );
end;
$$;

-- 8. RPC: load_post_detail ------------------------------------
-- Full post + author + memory metadata + comments (latest 50).

create or replace function public.load_post_detail(p_post_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_post    jsonb;
  v_comments jsonb;
  v_my_reaction text;
  v_user_id uuid := public.current_profile_id();
begin
  select to_jsonb(p) || jsonb_build_object(
    'author_name', up.full_name,
    'author_role', up.role,
    'author_photo_url', up.photo_url
  )
  into v_post
  from public.posts p
  join public.user_profiles up on up.id = p.author_id
  where p.id = p_post_id;

  if v_post is null then
    raise exception 'Post not found';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'post_id', c.post_id,
      'author_id', c.author_id,
      'body', c.body,
      'status', c.status,
      'created_at', c.created_at,
      'author_name', up.full_name
    ) order by c.created_at asc
  ), '[]'::jsonb)
  into v_comments
  from public.comments c
  join public.user_profiles up on up.id = c.author_id
  where c.post_id = p_post_id
    and c.status = 'approved'
  limit 50;

  select reaction_type into v_my_reaction
  from public.reactions
  where post_id = p_post_id and user_id = v_user_id;

  return v_post || jsonb_build_object(
    'comments', v_comments,
    'my_reaction', v_my_reaction
  );
end;
$$;

-- 9. Backfill existing data (idempotent) ----------------------

do $$
declare
  r record;
begin
  for r in select distinct post_id from public.reactions loop
    perform public.refresh_reaction_counts_for_post(r.post_id);
  end loop;
  for r in select distinct post_id from public.comments loop
    perform public.refresh_comment_count_for_post(r.post_id);
  end loop;
end;
$$;
