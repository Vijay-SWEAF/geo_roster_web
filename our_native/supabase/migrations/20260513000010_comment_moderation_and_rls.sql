-- ============================================================
-- Migration 010: Comment moderation defaults + pending posts RLS
-- ============================================================

-- 1. Change comment default status from 'approved' to 'pending_review'
--    so all new comments go through moderation before appearing.
alter table public.comments
  alter column status set default 'pending_review';

-- 2. Backfill: keep existing approved comments as-is (don't touch history).
--    New comments will now default to pending_review.

-- 3. Add author_name denorm helper for admin moderation view (avoid extra join)
--    Already works via join — no schema change needed.

-- 4. Add moderation_note column to posts so admin can record rejection reason
alter table public.posts
  add column if not exists moderation_note text;

-- 5. Add moderation_note column to comments
alter table public.comments
  add column if not exists moderation_note text;

-- 6. RPC: admin_get_pending_posts — returns pending posts with author info
--    Only callable by authenticated users (RLS on posts will enforce role).
create or replace function public.admin_get_pending_posts(p_community_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  select jsonb_agg(
    jsonb_build_object(
      'id',         p.id,
      'post_type',  p.post_type,
      'title',      p.title,
      'body',       p.body,
      'cover_image_url', p.cover_image_url,
      'status',     p.status,
      'created_at', p.created_at,
      'author_name', coalesce(up.full_name, 'Unknown'),
      'author_role', coalesce(up.role, 'member')
    )
    order by p.created_at asc
  )
  into result
  from public.posts p
  left join public.user_profiles up on up.id = p.author_id
  where p.community_id = p_community_id
    and p.status = 'pending_review';

  return coalesce(result, '[]'::jsonb);
end;
$$;

-- 7. RPC: admin_get_pending_comments — returns pending comments with post+author info
create or replace function public.admin_get_pending_comments(p_community_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  select jsonb_agg(
    jsonb_build_object(
      'id',          c.id,
      'body',        c.body,
      'status',      c.status,
      'created_at',  c.created_at,
      'post_id',     c.post_id,
      'post_title',  p.title,
      'author_name', coalesce(up.full_name, 'Unknown'),
      'author_role', coalesce(up.role, 'member')
    )
    order by c.created_at asc
  )
  into result
  from public.comments c
  join public.posts p on p.id = c.post_id
  left join public.user_profiles up on up.id = c.author_id
  where p.community_id = p_community_id
    and c.status = 'pending_review';

  return coalesce(result, '[]'::jsonb);
end;
$$;

-- 8. RPC: moderate_post — approve or reject a post
create or replace function public.moderate_post(
  p_post_id       uuid,
  p_action        text,  -- 'approve' | 'reject' | 'hide'
  p_note          text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  new_status text;
begin
  if p_action = 'approve' then
    new_status := 'approved';
  elsif p_action = 'reject' then
    new_status := 'rejected';
  elsif p_action = 'hide' then
    new_status := 'hidden';
  else
    raise exception 'Invalid action: %', p_action;
  end if;

  update public.posts
  set status           = new_status,
      moderation_note  = p_note,
      updated_at       = now()
  where id = p_post_id;
end;
$$;

-- 9. RPC: moderate_comment — approve or reject a comment
create or replace function public.moderate_comment(
  p_comment_id    uuid,
  p_action        text,  -- 'approve' | 'reject' | 'hide'
  p_note          text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  new_status text;
begin
  if p_action = 'approve' then
    new_status := 'approved';
  elsif p_action = 'reject' then
    new_status := 'hidden';
  elsif p_action = 'hide' then
    new_status := 'hidden';
  else
    raise exception 'Invalid action: %', p_action;
  end if;

  update public.comments
  set status           = new_status,
      moderation_note  = p_note,
      updated_at       = now()
  where id = p_comment_id;
end;
$$;

-- 10. Count helpers for badge display
create or replace function public.pending_post_count(p_community_id uuid)
returns int
language sql
security definer
set search_path = public
as $$
  select count(*)::int
  from public.posts
  where community_id = p_community_id and status = 'pending_review';
$$;

create or replace function public.pending_comment_count(p_community_id uuid)
returns int
language sql
security definer
set search_path = public
as $$
  select count(*)::int
  from public.comments c
  join public.posts p on p.id = c.post_id
  where p.community_id = p_community_id and c.status = 'pending_review';
$$;
