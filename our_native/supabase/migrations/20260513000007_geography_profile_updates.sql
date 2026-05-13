-- ============================================================
-- OurNative - Geography Profile Updates + Wadi Support
-- ============================================================
-- Idempotent: safe to re-run after partial failures.
-- Order: communities.village_id FIRST, then policies that join it.
-- ============================================================

-- STEP 1: communities.village_id (must exist before admin_write policy)

alter table public.communities
  add column if not exists village_id text references public.villages(id);

create unique index if not exists communities_village_id_unique
  on public.communities(village_id)
  where village_id is not null;

-- STEP 2: user_profiles new columns (wadi_id added as plain text first,
-- FK added after reference_wadis table exists in STEP 4)

alter table public.user_profiles
  add column if not exists village_id text references public.villages(id),
  add column if not exists wadi_id    text;

-- STEP 3: reference_wadis table

create table if not exists public.reference_wadis (
  id         text primary key,
  village_id text not null references public.villages(id),
  name       text not null,
  sort_order int  not null default 0
);

alter table public.reference_wadis enable row level security;

-- STEP 4: Add FK from user_profiles.wadi_id -> reference_wadis
-- Uses DO block because ADD CONSTRAINT IF NOT EXISTS is not valid syntax

do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'user_profiles_wadi_id_fkey'
      and table_name = 'user_profiles'
      and table_schema = 'public'
  ) then
    alter table public.user_profiles
      add constraint user_profiles_wadi_id_fkey
      foreign key (wadi_id) references public.reference_wadis(id);
  end if;
end;
$$;

-- STEP 5: RLS policies for reference_wadis

drop policy if exists "reference_wadis_select_authenticated" on public.reference_wadis;
create policy "reference_wadis_select_authenticated"
  on public.reference_wadis for select
  using (auth.uid() is not null);

-- communities.village_id now exists (added in STEP 1) so join is valid
drop policy if exists "reference_wadis_admin_write" on public.reference_wadis;
create policy "reference_wadis_admin_write"
  on public.reference_wadis for all
  using (
    exists (
      select 1
      from public.user_profiles up
      join public.communities c on c.id = up.community_id
      where up.user_id = auth.uid()
        and up.role in ('admin', 'moderator')
        and c.village_id = reference_wadis.village_id
    )
  );

-- STEP 6: Replace create_or_join_community RPC
-- Input:  p_village_id text
-- Output: jsonb { community_id uuid, is_creator bool }
-- is_creator=true  -> first user from village -> Flutter grants admin + auto-approves
-- is_creator=false -> subsequent users -> pending approval by admin

create or replace function public.create_or_join_community(
  p_village_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id      uuid    := auth.uid();
  v_community_id uuid;
  v_village_name text;
  v_is_creator   boolean := false;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_village_id is null or trim(p_village_id) = '' then
    raise exception 'Village must be selected';
  end if;

  select name into v_village_name
    from public.villages
   where id = p_village_id;

  if v_village_name is null then
    raise exception 'Invalid village id: %', p_village_id;
  end if;

  select id into v_community_id
    from public.communities
   where village_id = p_village_id
   limit 1;

  if v_community_id is null then
    insert into public.communities (
      name, village_id, is_private, created_by, description
    ) values (
      v_village_name,
      p_village_id,
      true,
      v_user_id,
      v_village_name || ' - OurNative Community'
    )
    returning id into v_community_id;

    v_is_creator := true;
  end if;

  return jsonb_build_object(
    'community_id', v_community_id,
    'is_creator',   v_is_creator
  );
end;
$$;
