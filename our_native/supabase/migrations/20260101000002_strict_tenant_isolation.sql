-- ============================================================
-- STRICT TENANT ISOLATION POLICIES
-- ============================================================

-- Helper: get current user's community id
create or replace function public.current_community_id()
returns uuid language sql stable as $$
  select community_id
  from public.user_profiles
  where user_id = auth.uid()
  limit 1;
$$;

-- COMMUNITIES

drop policy if exists "communities_select" on public.communities;
create policy "communities_select_member_only" on public.communities
  for select using (
    id = public.current_community_id()
  );

-- USER PROFILES

drop policy if exists "profiles_select_own" on public.user_profiles;
create policy "profiles_select_same_community" on public.user_profiles
  for select using (
    auth.uid() = user_id
    or (
      community_id is not null
      and community_id = public.current_community_id()
    )
  );

-- POSTS

drop policy if exists "posts_select_approved" on public.posts;
drop policy if exists "posts_insert" on public.posts;
drop policy if exists "posts_update_own" on public.posts;

create policy "posts_select_scoped" on public.posts
  for select using (
    community_id = public.current_community_id()
    and (
      status = 'approved'
      or author_id = public.current_profile_id()
      or public.current_user_role(community_id) in ('moderator','admin')
    )
  );

create policy "posts_insert_scoped" on public.posts
  for insert with check (
    author_id = public.current_profile_id()
    and community_id = public.current_community_id()
  );

create policy "posts_update_scoped" on public.posts
  for update using (
    community_id = public.current_community_id()
    and (
      author_id = public.current_profile_id()
      or public.current_user_role(community_id) in ('moderator','admin')
    )
  );

-- EVENTS

drop policy if exists "events_select" on public.events;
drop policy if exists "events_insert" on public.events;

create policy "events_select_scoped" on public.events
  for select using (
    community_id = public.current_community_id()
  );

create policy "events_insert_scoped" on public.events
  for insert with check (
    community_id = public.current_community_id()
    and (
      public.current_user_role(community_id) in ('admin','moderator')
      or organizer_id = public.current_profile_id()
    )
  );

-- EVENT RSVPS

drop policy if exists "rsvps_select" on public.event_rsvps;
drop policy if exists "rsvps_insert_own" on public.event_rsvps;
drop policy if exists "rsvps_update_own" on public.event_rsvps;

create policy "rsvps_select_scoped" on public.event_rsvps
  for select using (
    exists (
      select 1 from public.events e
      where e.id = event_id
        and e.community_id = public.current_community_id()
    )
  );

create policy "rsvps_insert_scoped" on public.event_rsvps
  for insert with check (
    user_id = public.current_profile_id()
    and exists (
      select 1 from public.events e
      where e.id = event_id
        and e.community_id = public.current_community_id()
    )
  );

create policy "rsvps_update_scoped" on public.event_rsvps
  for update using (
    user_id = public.current_profile_id()
    and exists (
      select 1 from public.events e
      where e.id = event_id
        and e.community_id = public.current_community_id()
    )
  );

-- COMMENTS

drop policy if exists "comments_select" on public.comments;
drop policy if exists "comments_insert" on public.comments;
drop policy if exists "comments_update_own" on public.comments;

create policy "comments_select_scoped" on public.comments
  for select using (
    exists (
      select 1 from public.posts p
      where p.id = post_id
        and p.community_id = public.current_community_id()
        and (status = 'approved' or author_id = public.current_profile_id())
    )
  );

create policy "comments_insert_scoped" on public.comments
  for insert with check (
    author_id = public.current_profile_id()
    and exists (
      select 1 from public.posts p
      where p.id = post_id
        and p.community_id = public.current_community_id()
    )
  );

create policy "comments_update_scoped" on public.comments
  for update using (
    exists (
      select 1 from public.posts p
      where p.id = post_id
        and p.community_id = public.current_community_id()
    )
    and (
      author_id = public.current_profile_id()
      or exists (
        select 1 from public.posts p
        join public.user_profiles up on up.community_id = p.community_id
        where p.id = post_id
          and up.user_id = auth.uid()
          and up.role in ('moderator','admin')
      )
    )
  );

-- REACTIONS

drop policy if exists "reactions_select" on public.reactions;
drop policy if exists "reactions_insert_own" on public.reactions;
drop policy if exists "reactions_delete_own" on public.reactions;

create policy "reactions_select_scoped" on public.reactions
  for select using (
    exists (
      select 1 from public.posts p
      where p.id = post_id
        and p.community_id = public.current_community_id()
    )
  );

create policy "reactions_insert_scoped" on public.reactions
  for insert with check (
    user_id = public.current_profile_id()
    and exists (
      select 1 from public.posts p
      where p.id = post_id
        and p.community_id = public.current_community_id()
    )
  );

create policy "reactions_delete_scoped" on public.reactions
  for delete using (
    user_id = public.current_profile_id()
    and exists (
      select 1 from public.posts p
      where p.id = post_id
        and p.community_id = public.current_community_id()
    )
  );

-- MEDIA FILES

drop policy if exists "media_select_public" on public.media_files;
drop policy if exists "media_insert_own" on public.media_files;

create policy "media_select_scoped" on public.media_files
  for select using (
    community_id = public.current_community_id()
  );

create policy "media_insert_scoped" on public.media_files
  for insert with check (
    uploaded_by = public.current_profile_id()
    and community_id = public.current_community_id()
  );
