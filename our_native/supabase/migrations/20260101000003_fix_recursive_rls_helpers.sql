-- ============================================================
-- FIX RECURSIVE RLS HELPER FUNCTIONS
-- ============================================================
--
-- The tenant-isolation policies call helper functions that read from
-- public.user_profiles. Without SECURITY DEFINER, those helpers are
-- subject to the same RLS policies and recurse into themselves.
--
-- This migration makes the helpers bypass RLS safely.

create or replace function public.current_community_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select community_id
  from public.user_profiles
  where user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.user_profiles
  where user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_user_role(p_community_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.user_profiles
  where user_id = auth.uid()
    and community_id = p_community_id
  limit 1;
$$;
