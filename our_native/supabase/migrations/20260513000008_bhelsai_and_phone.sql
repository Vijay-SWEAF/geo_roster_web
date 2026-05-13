-- ============================================================
-- OurNative - Bhelsai Village + Wadis + Phone Auth Columns
-- ============================================================

-- Phone number fields for OTP auth support

alter table public.user_profiles
  add column if not exists phone          text,
  add column if not exists phone_verified boolean not null default false;

-- Bhelsai village under Ratnagiri > Khed (taluka id: rt-khed)

insert into public.villages (id, taluka_id, name, sort_order)
values ('rt-khed-bhelsai', 'rt-khed', 'Bhelsai', 6)
on conflict (id) do nothing;

-- Bhelsai wadis

insert into public.reference_wadis (id, village_id, name, sort_order) values
  ('rt-khed-bhelsai-w1', 'rt-khed-bhelsai', 'Bara Aane Gaonthan', 1),
  ('rt-khed-bhelsai-w2', 'rt-khed-bhelsai', 'Budhawadi',          2),
  ('rt-khed-bhelsai-w3', 'rt-khed-bhelsai', 'Chauthai',           3)
on conflict (id) do nothing;
