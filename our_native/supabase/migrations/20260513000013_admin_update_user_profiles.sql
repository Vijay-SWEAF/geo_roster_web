-- Allow community admins/moderators to update member profiles in their own community.
-- This is required for member approval and role management to persist in the database.

drop policy if exists "profiles_update_community_admin" on public.user_profiles;

create policy "profiles_update_community_admin" on public.user_profiles
  for update
  using (
    community_id is not null
    and community_id = public.current_community_id()
    and public.current_user_role(community_id) in ('admin', 'moderator')
  )
  with check (
    community_id is not null
    and community_id = public.current_community_id()
    and public.current_user_role(community_id) in ('admin', 'moderator')
  );