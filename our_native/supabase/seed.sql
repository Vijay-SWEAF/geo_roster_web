-- ============================================================
-- OurNative - Seed Data (Demo Community + Admin)
-- ============================================================

-- Insert a demo community for development
insert into public.communities (id, name, location, description, is_private, created_at)
values (
  '00000000-0000-0000-0000-000000000001',
  'Apulki Village',
  'Maharashtra, India',
  'A peaceful community to preserve our village memories and rebuild bonds.',
  false,
  now()
)
on conflict (id) do nothing;
