-- ============================================================
-- Migration 011: In-app notifications
-- ============================================================

-- 1. notifications table
create table if not exists public.notifications (
  id            uuid primary key default gen_random_uuid(),
  recipient_id  uuid not null references public.user_profiles(id) on delete cascade,
  community_id  uuid not null references public.communities(id) on delete cascade,
  type          text not null,         -- 'comment_on_post' | 'rsvp_on_event' | 'post_approved' | 'post_rejected' | 'comment_approved' | 'comment_rejected'
  title         text not null,
  body          text not null,
  actor_name    text,                  -- who triggered it (denorm)
  entity_id     uuid,                  -- post_id / event_id / comment_id
  entity_type   text,                  -- 'post' | 'event' | 'comment'
  is_read       boolean not null default false,
  created_at    timestamptz not null default now()
);

create index if not exists idx_notifications_recipient
  on public.notifications(recipient_id, is_read, created_at desc);

-- 2. RLS
alter table public.notifications enable row level security;

-- Users can only read their own notifications
create policy "users_select_own_notifications"
  on public.notifications for select
  using (
    recipient_id = (
      select id from public.user_profiles where user_id = auth.uid() limit 1
    )
  );

-- Users can mark their own notifications as read
create policy "users_update_own_notifications"
  on public.notifications for update
  using (
    recipient_id = (
      select id from public.user_profiles where user_id = auth.uid() limit 1
    )
  )
  with check (
    recipient_id = (
      select id from public.user_profiles where user_id = auth.uid() limit 1
    )
  );

-- Service role / triggers insert notifications
create policy "service_insert_notifications"
  on public.notifications for insert
  with check (true);

-- Users can delete their own notifications
create policy "users_delete_own_notifications"
  on public.notifications for delete
  using (
    recipient_id = (
      select id from public.user_profiles where user_id = auth.uid() limit 1
    )
  );

-- 3. Realtime: enable for notifications table
alter publication supabase_realtime add table public.notifications;

-- ============================================================
-- TRIGGER: notify post author when a comment is approved
-- ============================================================
create or replace function public.notify_comment_on_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post        record;
  v_actor_name  text;
begin
  -- Only fire when a comment is approved (status set to 'approved')
  if NEW.status <> 'approved' then
    return NEW;
  end if;
  if OLD.status = 'approved' then
    return NEW;  -- already was approved, skip
  end if;

  -- Get post + author info
  select p.author_id, p.title, p.community_id
  into v_post
  from public.posts p
  where p.id = NEW.post_id;

  if not found then return NEW; end if;

  -- Don't notify if commenter == post author
  if NEW.author_id = v_post.author_id then return NEW; end if;

  -- Get commenter name
  select coalesce(full_name, 'Someone')
  into v_actor_name
  from public.user_profiles
  where id = NEW.author_id;

  insert into public.notifications
    (recipient_id, community_id, type, title, body, actor_name, entity_id, entity_type)
  values
    (v_post.author_id, v_post.community_id,
     'comment_on_post',
     'New comment on your post',
     v_actor_name || ' commented on "' || coalesce(v_post.title, 'your post') || '"',
     v_actor_name,
     NEW.post_id,
     'post');

  return NEW;
end;
$$;

drop trigger if exists trg_notify_comment_on_post on public.comments;
create trigger trg_notify_comment_on_post
  after update of status on public.comments
  for each row execute function public.notify_comment_on_post();

-- ============================================================
-- TRIGGER: notify event organiser when someone RSVPs as 'going'
-- ============================================================
create or replace function public.notify_rsvp_on_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event       record;
  v_actor_name  text;
begin
  -- Only notify on 'going'
  if NEW.status <> 'going' then return NEW; end if;

  select e.organiser_id, e.title, e.community_id
  into v_event
  from public.events e
  where e.id = NEW.event_id;

  if not found then return NEW; end if;
  if NEW.user_id = v_event.organiser_id then return NEW; end if;

  select coalesce(full_name, 'Someone')
  into v_actor_name
  from public.user_profiles
  where id = NEW.user_id;

  insert into public.notifications
    (recipient_id, community_id, type, title, body, actor_name, entity_id, entity_type)
  values
    (v_event.organiser_id, v_event.community_id,
     'rsvp_on_event',
     'Someone is going to your event',
     v_actor_name || ' is going to "' || coalesce(v_event.title, 'your event') || '"',
     v_actor_name,
     NEW.event_id,
     'event');

  return NEW;
end;
$$;

drop trigger if exists trg_notify_rsvp_on_event on public.event_rsvps;
create trigger trg_notify_rsvp_on_event
  after insert or update of status on public.event_rsvps
  for each row execute function public.notify_rsvp_on_event();

-- ============================================================
-- TRIGGER: notify post author when post is approved or rejected
-- ============================================================
create or replace function public.notify_post_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_notif_type  text;
  v_title       text;
  v_body        text;
begin
  if NEW.status = OLD.status then return NEW; end if;

  if NEW.status = 'approved' then
    v_notif_type := 'post_approved';
    v_title := 'Your post is live!';
    v_body  := 'Your post "' || coalesce(NEW.title, 'Untitled') || '" has been approved.';
  elsif NEW.status = 'rejected' then
    v_notif_type := 'post_rejected';
    v_title := 'Your post was not approved';
    v_body  := 'Your post "' || coalesce(NEW.title, 'Untitled') || '" was rejected'
               || case when NEW.moderation_note is not null
                    then ': ' || NEW.moderation_note
                    else '.' end;
  else
    return NEW;
  end if;

  insert into public.notifications
    (recipient_id, community_id, type, title, body, entity_id, entity_type)
  values
    (NEW.author_id, NEW.community_id, v_notif_type, v_title, v_body, NEW.id, 'post');

  return NEW;
end;
$$;

drop trigger if exists trg_notify_post_moderation on public.posts;
create trigger trg_notify_post_moderation
  after update of status on public.posts
  for each row execute function public.notify_post_moderation();

-- ============================================================
-- RPC: mark_all_notifications_read — marks all unread for caller
-- ============================================================
create or replace function public.mark_all_notifications_read(p_community_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
begin
  select id into v_profile_id
  from public.user_profiles
  where user_id = auth.uid()
  limit 1;

  if v_profile_id is null then return; end if;

  update public.notifications
  set is_read = true
  where recipient_id = v_profile_id
    and community_id = p_community_id
    and is_read = false;
end;
$$;
