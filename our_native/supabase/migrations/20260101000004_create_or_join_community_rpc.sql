-- ============================================================
-- JOIN COMMUNITY RPC
-- ============================================================
--
-- Profile setup needs to either reuse an existing community by name or
-- create a new one for the user. With strict community RLS, client-side
-- lookup on public.communities is intentionally blocked before the user
-- has a profile, so this RPC performs the lookup and insert safely as
-- SECURITY DEFINER.

create or replace function public.create_or_join_community(
  p_name text,
  p_location text default null,
  p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_community_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select id
    into v_community_id
  from public.communities
  where lower(name) = lower(trim(p_name))
  limit 1;

  if v_community_id is null then
    insert into public.communities (
      name,
      location,
      description,
      is_private,
      created_by
    ) values (
      trim(p_name),
      nullif(trim(p_location), ''),
      coalesce(nullif(trim(p_description), ''), 'Community for ' || trim(p_name)),
      true,
      v_user_id
    )
    returning id into v_community_id;
  end if;

  return v_community_id;
end;
$$;
