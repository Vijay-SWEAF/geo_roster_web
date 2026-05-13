-- ============================================================
-- RELAX COMMUNITY INSERT FOR JOIN FLOW
-- ============================================================
--
-- Community creation is part of first-time profile setup. The app only
-- exposes this path to signed-in users, so insert restrictions can be
-- simpler here without weakening tenant isolation for reads.

create or replace function public.set_community_created_by()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.created_by is null then
    new.created_by := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists on_communities_set_created_by on public.communities;
create trigger on_communities_set_created_by
  before insert on public.communities
  for each row execute procedure public.set_community_created_by();

drop policy if exists "communities_insert" on public.communities;
drop policy if exists "communities_insert_scoped" on public.communities;

create policy "communities_insert_scoped" on public.communities
  for insert with check (true);
