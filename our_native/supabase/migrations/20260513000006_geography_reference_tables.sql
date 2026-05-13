-- ============================================================
-- OurNative - Geography Reference Tables
-- Districts → Talukas → Villages (Konkan Maharashtra)
-- ============================================================
-- These are read-only master data tables.
-- RLS allows any authenticated user to SELECT (needed during profile setup
-- before the user has a community_id).
-- ============================================================

-- DISTRICTS

create table public.districts (
  id         text primary key,
  name       text not null,
  state      text not null default 'Maharashtra',
  sort_order int  not null default 0
);

alter table public.districts enable row level security;

create policy "districts_select_authenticated"
  on public.districts for select
  using (auth.uid() is not null);

-- TALUKAS

create table public.talukas (
  id          text primary key,
  district_id text not null references public.districts(id),
  name        text not null,
  sort_order  int  not null default 0
);

alter table public.talukas enable row level security;

create policy "talukas_select_authenticated"
  on public.talukas for select
  using (auth.uid() is not null);

-- VILLAGES

create table public.villages (
  id         text primary key,
  taluka_id  text not null references public.talukas(id),
  name       text not null,
  sort_order int  not null default 0
);

alter table public.villages enable row level security;

create policy "villages_select_authenticated"
  on public.villages for select
  using (auth.uid() is not null);

-- ============================================================
-- SEED DATA
-- ============================================================

-- ── DISTRICTS ────────────────────────────────────────────────

insert into public.districts (id, name, sort_order) values
  ('raigad',      'Raigad',      1),
  ('ratnagiri',   'Ratnagiri',   2),
  ('sindhudurg',  'Sindhudurg',  3);

-- ── TALUKAS ──────────────────────────────────────────────────

-- Raigad (15 talukas)
insert into public.talukas (id, district_id, name, sort_order) values
  ('rg-alibag',      'raigad', 'Alibag',      1),
  ('rg-karjat',      'raigad', 'Karjat',      2),
  ('rg-khalapur',    'raigad', 'Khalapur',    3),
  ('rg-mahad',       'raigad', 'Mahad',       4),
  ('rg-mangaon',     'raigad', 'Mangaon',     5),
  ('rg-mhasla',      'raigad', 'Mhasla',      6),
  ('rg-murud',       'raigad', 'Murud',       7),
  ('rg-panvel',      'raigad', 'Panvel',      8),
  ('rg-pen',         'raigad', 'Pen',         9),
  ('rg-poladpur',    'raigad', 'Poladpur',    10),
  ('rg-roha',        'raigad', 'Roha',        11),
  ('rg-shrivardhan', 'raigad', 'Shrivardhan', 12),
  ('rg-sudhagad',    'raigad', 'Sudhagad',    13),
  ('rg-tala',        'raigad', 'Tala',        14),
  ('rg-uran',        'raigad', 'Uran',        15);

-- Ratnagiri (9 talukas)
insert into public.talukas (id, district_id, name, sort_order) values
  ('rt-chiplun',       'ratnagiri', 'Chiplun',       1),
  ('rt-dapoli',        'ratnagiri', 'Dapoli',        2),
  ('rt-guhagar',       'ratnagiri', 'Guhagar',       3),
  ('rt-khed',          'ratnagiri', 'Khed',          4),
  ('rt-lanja',         'ratnagiri', 'Lanja',         5),
  ('rt-mandangad',     'ratnagiri', 'Mandangad',     6),
  ('rt-rajapur',       'ratnagiri', 'Rajapur',       7),
  ('rt-ratnagiri',     'ratnagiri', 'Ratnagiri',     8),
  ('rt-sangameshwar',  'ratnagiri', 'Sangameshwar',  9);

-- Sindhudurg (8 talukas)
insert into public.talukas (id, district_id, name, sort_order) values
  ('sd-devgad',       'sindhudurg', 'Devgad',       1),
  ('sd-dodamarg',     'sindhudurg', 'Dodamarg',     2),
  ('sd-kankavli',     'sindhudurg', 'Kankavli',     3),
  ('sd-kudal',        'sindhudurg', 'Kudal',        4),
  ('sd-malvan',       'sindhudurg', 'Malvan',       5),
  ('sd-sawantwadi',   'sindhudurg', 'Sawantwadi',   6),
  ('sd-vaibhavwadi',  'sindhudurg', 'Vaibhavwadi',  7),
  ('sd-vengurla',     'sindhudurg', 'Vengurla',     8);

-- ── VILLAGES ─────────────────────────────────────────────────

-- Raigad › Alibag
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-alibag-akshi',       'rg-alibag', 'Akshi',         1),
  ('rg-alibag-alibag',      'rg-alibag', 'Alibag',        2),
  ('rg-alibag-borli',       'rg-alibag', 'Borli',         3),
  ('rg-alibag-chaul',       'rg-alibag', 'Chaul',         4),
  ('rg-alibag-kihim',       'rg-alibag', 'Kihim',         5),
  ('rg-alibag-korlai',      'rg-alibag', 'Korlai',        6),
  ('rg-alibag-mandwa',      'rg-alibag', 'Mandwa',        7),
  ('rg-alibag-nagaon',      'rg-alibag', 'Nagaon',        8),
  ('rg-alibag-rajapuri',    'rg-alibag', 'Rajapuri',      9),
  ('rg-alibag-revdanda',    'rg-alibag', 'Revdanda',      10),
  ('rg-alibag-rewas',       'rg-alibag', 'Rewas',         11),
  ('rg-alibag-sarsole',     'rg-alibag', 'Sarsole',       12),
  ('rg-alibag-thal',        'rg-alibag', 'Thal',          13),
  ('rg-alibag-varsoli',     'rg-alibag', 'Varsoli',       14);

-- Raigad › Karjat
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-karjat-karjat',      'rg-karjat', 'Karjat',        1),
  ('rg-karjat-kashele',     'rg-karjat', 'Kashele',       2),
  ('rg-karjat-khopoli',     'rg-karjat', 'Khopoli',       3),
  ('rg-karjat-matheran',    'rg-karjat', 'Matheran',      4),
  ('rg-karjat-neral',       'rg-karjat', 'Neral',         5),
  ('rg-karjat-vangani',     'rg-karjat', 'Vangani',       6);

-- Raigad › Khalapur
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-khalapur-khopoli',   'rg-khalapur', 'Khopoli',     1),
  ('rg-khalapur-palaspe',   'rg-khalapur', 'Palaspe',     2),
  ('rg-khalapur-rasayani',  'rg-khalapur', 'Rasayani',    3);

-- Raigad › Mahad
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-mahad-birwadi',      'rg-mahad', 'Birwadi',        1),
  ('rg-mahad-goregaon',     'rg-mahad', 'Goregaon',       2),
  ('rg-mahad-mahad',        'rg-mahad', 'Mahad',          3),
  ('rg-mahad-vanzol',       'rg-mahad', 'Vanzol',         4);

-- Raigad › Mangaon
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-mangaon-goregaon',   'rg-mangaon', 'Goregaon',     1),
  ('rg-mangaon-mangaon',    'rg-mangaon', 'Mangaon',      2),
  ('rg-mangaon-shirki',     'rg-mangaon', 'Shirki',       3);

-- Raigad › Mhasla
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-mhasla-ghol',        'rg-mhasla', 'Ghol',          1),
  ('rg-mhasla-mhasla',      'rg-mhasla', 'Mhasla',        2);

-- Raigad › Murud
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-murud-ekdara',       'rg-murud', 'Ekdara',         1),
  ('rg-murud-kashid',       'rg-murud', 'Kashid',         2),
  ('rg-murud-murud',        'rg-murud', 'Murud',          3),
  ('rg-murud-nandgaon',     'rg-murud', 'Nandgaon',       4),
  ('rg-murud-rajapuri',     'rg-murud', 'Rajapuri',       5);

-- Raigad › Panvel
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-panvel-belapur',     'rg-panvel', 'Belapur',        1),
  ('rg-panvel-karanjade',   'rg-panvel', 'Karanjade',      2),
  ('rg-panvel-kharghar',    'rg-panvel', 'Kharghar',       3),
  ('rg-panvel-new-panvel',  'rg-panvel', 'New Panvel',     4),
  ('rg-panvel-panvel',      'rg-panvel', 'Panvel',         5),
  ('rg-panvel-taloja',      'rg-panvel', 'Taloja',         6),
  ('rg-panvel-ulwe',        'rg-panvel', 'Ulwe',           7);

-- Raigad › Pen
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-pen-chondi',         'rg-pen', 'Chondi',           1),
  ('rg-pen-kharpada',       'rg-pen', 'Kharpada',         2),
  ('rg-pen-khandalwadi',    'rg-pen', 'Khandalwadi',      3),
  ('rg-pen-nandgaon',       'rg-pen', 'Nandgaon',         4),
  ('rg-pen-pen',            'rg-pen', 'Pen',              5),
  ('rg-pen-saravali',       'rg-pen', 'Saravali',         6);

-- Raigad › Poladpur
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-poladpur-bam',       'rg-poladpur', 'Bam',          1),
  ('rg-poladpur-kondvhal',  'rg-poladpur', 'Kondvhal',     2),
  ('rg-poladpur-poladpur',  'rg-poladpur', 'Poladpur',     3),
  ('rg-poladpur-tale',      'rg-poladpur', 'Tale',         4);

-- Raigad › Roha
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-roha-jambhe',        'rg-roha', 'Jambhe',          1),
  ('rg-roha-nagothane',     'rg-roha', 'Nagothane',       2),
  ('rg-roha-pofran',        'rg-roha', 'Pofran',          3),
  ('rg-roha-roha',          'rg-roha', 'Roha',            4),
  ('rg-roha-varas',         'rg-roha', 'Varas',           5);

-- Raigad › Shrivardhan
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-shrivardhan-bagmandla',   'rg-shrivardhan', 'Bagmandla',   1),
  ('rg-shrivardhan-diveagar',    'rg-shrivardhan', 'Diveagar',    2),
  ('rg-shrivardhan-harihareshwar','rg-shrivardhan','Harihareshwar',3),
  ('rg-shrivardhan-shrivardhan', 'rg-shrivardhan', 'Shrivardhan', 4);

-- Raigad › Sudhagad
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-sudhagad-ambivali',  'rg-sudhagad', 'Ambivali',    1),
  ('rg-sudhagad-pali',      'rg-sudhagad', 'Pali',        2),
  ('rg-sudhagad-sakhar',    'rg-sudhagad', 'Sakhar',      3),
  ('rg-sudhagad-varand',    'rg-sudhagad', 'Varand',      4);

-- Raigad › Tala
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-tala-kamble',        'rg-tala', 'Kamble',          1),
  ('rg-tala-nizampur',      'rg-tala', 'Nizampur',        2),
  ('rg-tala-tala',          'rg-tala', 'Tala',            3);

-- Raigad › Uran
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rg-uran-jasai',         'rg-uran', 'Jasai',           1),
  ('rg-uran-koproli',       'rg-uran', 'Koproli',         2),
  ('rg-uran-nhava',         'rg-uran', 'Nhava',           3),
  ('rg-uran-uran',          'rg-uran', 'Uran',            4);

-- ── Ratnagiri Villages ────────────────────────────────────────

-- Ratnagiri › Chiplun
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rt-chiplun-chiplun',    'rt-chiplun', 'Chiplun',      1),
  ('rt-chiplun-dabhil',     'rt-chiplun', 'Dabhil',       2),
  ('rt-chiplun-kamathe',    'rt-chiplun', 'Kamathe',      3),
  ('rt-chiplun-kherdi',     'rt-chiplun', 'Kherdi',       4),
  ('rt-chiplun-mhapral',    'rt-chiplun', 'Mhapral',      5),
  ('rt-chiplun-nive',       'rt-chiplun', 'Nive',         6);

-- Ratnagiri › Dapoli
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rt-dapoli-anjarle',     'rt-dapoli', 'Anjarle',       1),
  ('rt-dapoli-burondi',     'rt-dapoli', 'Burondi',       2),
  ('rt-dapoli-dabhol',      'rt-dapoli', 'Dabhol',        3),
  ('rt-dapoli-dapoli',      'rt-dapoli', 'Dapoli',        4),
  ('rt-dapoli-harne',       'rt-dapoli', 'Harne',         5),
  ('rt-dapoli-karde',       'rt-dapoli', 'Karde',         6),
  ('rt-dapoli-kelashi',     'rt-dapoli', 'Kelashi',       7),
  ('rt-dapoli-ladghar',     'rt-dapoli', 'Ladghar',       8),
  ('rt-dapoli-murud',       'rt-dapoli', 'Murud',         9);

-- Ratnagiri › Guhagar
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rt-guhagar-adasal',     'rt-guhagar', 'Adasal',       1),
  ('rt-guhagar-anjanvel',   'rt-guhagar', 'Anjanvel',     2),
  ('rt-guhagar-aravali',    'rt-guhagar', 'Aravali',      3),
  ('rt-guhagar-asud',       'rt-guhagar', 'Asud',         4),
  ('rt-guhagar-dhamapur',   'rt-guhagar', 'Dhamapur',     5),
  ('rt-guhagar-guhagar',    'rt-guhagar', 'Guhagar',      6),
  ('rt-guhagar-hedvi',      'rt-guhagar', 'Hedvi',        7),
  ('rt-guhagar-tavsal',     'rt-guhagar', 'Tavsal',       8),
  ('rt-guhagar-velneshwar', 'rt-guhagar', 'Velneshwar',   9);

-- Ratnagiri › Khed
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rt-khed-dabhil',        'rt-khed', 'Dabhil',          1),
  ('rt-khed-kalamb',        'rt-khed', 'Kalamb',          2),
  ('rt-khed-khed',          'rt-khed', 'Khed',            3),
  ('rt-khed-kotawade',      'rt-khed', 'Kotawade',        4),
  ('rt-khed-unhavre',       'rt-khed', 'Unhavre',         5);

-- Ratnagiri › Lanja
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rt-lanja-kharepatan',   'rt-lanja', 'Kharepatan',     1),
  ('rt-lanja-lanja',        'rt-lanja', 'Lanja',          2),
  ('rt-lanja-phansop',      'rt-lanja', 'Phansop',        3);

-- Ratnagiri › Mandangad
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rt-mandangad-bankot',   'rt-mandangad', 'Bankot',      1),
  ('rt-mandangad-mandangad','rt-mandangad', 'Mandangad',   2),
  ('rt-mandangad-palshet',  'rt-mandangad', 'Palshet',     3),
  ('rt-mandangad-shivthar', 'rt-mandangad', 'Shivthar',    4),
  ('rt-mandangad-velas',    'rt-mandangad', 'Velas',       5);

-- Ratnagiri › Rajapur
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rt-rajapur-ambolgad',   'rt-rajapur', 'Ambolgad',     1),
  ('rt-rajapur-masure',     'rt-rajapur', 'Masure',       2),
  ('rt-rajapur-nate',       'rt-rajapur', 'Nate',         3),
  ('rt-rajapur-palgad',     'rt-rajapur', 'Palgad',       4),
  ('rt-rajapur-rajapur',    'rt-rajapur', 'Rajapur',      5);

-- Ratnagiri › Ratnagiri
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rt-ratnagiri-aare-ware',   'rt-ratnagiri', 'Aare-Ware',   1),
  ('rt-ratnagiri-bhatye',      'rt-ratnagiri', 'Bhatye',      2),
  ('rt-ratnagiri-ganpatipule', 'rt-ratnagiri', 'Ganpatipule', 3),
  ('rt-ratnagiri-govalkot',    'rt-ratnagiri', 'Govalkot',    4),
  ('rt-ratnagiri-jaigad',      'rt-ratnagiri', 'Jaigad',      5),
  ('rt-ratnagiri-malgund',     'rt-ratnagiri', 'Malgund',     6),
  ('rt-ratnagiri-mirya',       'rt-ratnagiri', 'Mirya',       7),
  ('rt-ratnagiri-pawas',       'rt-ratnagiri', 'Pawas',       8),
  ('rt-ratnagiri-purnagad',    'rt-ratnagiri', 'Purnagad',    9),
  ('rt-ratnagiri-ratnagiri',   'rt-ratnagiri', 'Ratnagiri',   10),
  ('rt-ratnagiri-thibaw',      'rt-ratnagiri', 'Thibaw',      11);

-- Ratnagiri › Sangameshwar
insert into public.villages (id, taluka_id, name, sort_order) values
  ('rt-sangameshwar-deorukh',     'rt-sangameshwar', 'Deorukh',     1),
  ('rt-sangameshwar-gotavali',    'rt-sangameshwar', 'Gotavali',    2),
  ('rt-sangameshwar-sangameshwar','rt-sangameshwar', 'Sangameshwar',3),
  ('rt-sangameshwar-uktadi',      'rt-sangameshwar', 'Uktadi',      4);

-- ── Sindhudurg Villages ───────────────────────────────────────

-- Sindhudurg › Devgad
insert into public.villages (id, taluka_id, name, sort_order) values
  ('sd-devgad-bhogwe',      'sd-devgad', 'Bhogwe',        1),
  ('sd-devgad-devgad',      'sd-devgad', 'Devgad',        2),
  ('sd-devgad-girye',       'sd-devgad', 'Girye',         3),
  ('sd-devgad-kelus',       'sd-devgad', 'Kelus',         4),
  ('sd-devgad-kunkeshwar',  'sd-devgad', 'Kunkeshwar',    5),
  ('sd-devgad-mithbav',     'sd-devgad', 'Mithbav',       6),
  ('sd-devgad-padel',       'sd-devgad', 'Padel',         7),
  ('sd-devgad-vijaydurg',   'sd-devgad', 'Vijaydurg',     8);

-- Sindhudurg › Dodamarg
insert into public.villages (id, taluka_id, name, sort_order) values
  ('sd-dodamarg-amboli',    'sd-dodamarg', 'Amboli',       1),
  ('sd-dodamarg-dodamarg',  'sd-dodamarg', 'Dodamarg',     2),
  ('sd-dodamarg-haloli',    'sd-dodamarg', 'Haloli',       3),
  ('sd-dodamarg-naneli',    'sd-dodamarg', 'Naneli',       4);

-- Sindhudurg › Kankavli
insert into public.villages (id, taluka_id, name, sort_order) values
  ('sd-kankavli-asangaon',  'sd-kankavli', 'Asangaon',    1),
  ('sd-kankavli-bambarde',  'sd-kankavli', 'Bambarde',    2),
  ('sd-kankavli-kankavli',  'sd-kankavli', 'Kankavli',    3),
  ('sd-kankavli-oros',      'sd-kankavli', 'Oros',        4);

-- Sindhudurg › Kudal
insert into public.villages (id, taluka_id, name, sort_order) values
  ('sd-kudal-kasal',        'sd-kudal', 'Kasal',          1),
  ('sd-kudal-kudal',        'sd-kudal', 'Kudal',          2),
  ('sd-kudal-nimbavali',    'sd-kudal', 'Nimbavali',      3),
  ('sd-kudal-padve',        'sd-kudal', 'Padve',          4),
  ('sd-kudal-zarap',        'sd-kudal', 'Zarap',          5);

-- Sindhudurg › Malvan
insert into public.villages (id, taluka_id, name, sort_order) values
  ('sd-malvan-achara',      'sd-malvan', 'Achara',        1),
  ('sd-malvan-chivla',      'sd-malvan', 'Chivla',        2),
  ('sd-malvan-devbag',      'sd-malvan', 'Devbag',        3),
  ('sd-malvan-katta',       'sd-malvan', 'Katta',         4),
  ('sd-malvan-malvan',      'sd-malvan', 'Malvan',        5),
  ('sd-malvan-mogrul',      'sd-malvan', 'Mogrul',        6),
  ('sd-malvan-shiroda',     'sd-malvan', 'Shiroda',       7),
  ('sd-malvan-tarkarli',    'sd-malvan', 'Tarkarli',      8);

-- Sindhudurg › Sawantwadi
insert into public.villages (id, taluka_id, name, sort_order) values
  ('sd-sawantwadi-adeli',       'sd-sawantwadi', 'Adeli',       1),
  ('sd-sawantwadi-banda',       'sd-sawantwadi', 'Banda',       2),
  ('sd-sawantwadi-maneri',      'sd-sawantwadi', 'Maneri',      3),
  ('sd-sawantwadi-nandos',      'sd-sawantwadi', 'Nandos',      4),
  ('sd-sawantwadi-nerur',       'sd-sawantwadi', 'Nerur',       5),
  ('sd-sawantwadi-patgaon',     'sd-sawantwadi', 'Patgaon',     6),
  ('sd-sawantwadi-pinguli',     'sd-sawantwadi', 'Pinguli',     7),
  ('sd-sawantwadi-sarjekot',    'sd-sawantwadi', 'Sarjekot',    8),
  ('sd-sawantwadi-sawantwadi',  'sd-sawantwadi', 'Sawantwadi',  9),
  ('sd-sawantwadi-shiroda',     'sd-sawantwadi', 'Shiroda',     10),
  ('sd-sawantwadi-tulas',       'sd-sawantwadi', 'Tulas',       11);

-- Sindhudurg › Vaibhavwadi
insert into public.villages (id, taluka_id, name, sort_order) values
  ('sd-vaibhavwadi-bhuibavda',  'sd-vaibhavwadi', 'Bhuibavda',  1),
  ('sd-vaibhavwadi-harsul',     'sd-vaibhavwadi', 'Harsul',     2),
  ('sd-vaibhavwadi-vaibhavwadi','sd-vaibhavwadi', 'Vaibhavwadi',3);

-- Sindhudurg › Vengurla
insert into public.villages (id, taluka_id, name, sort_order) values
  ('sd-vengurla-aravali',   'sd-vengurla', 'Aravali',     1),
  ('sd-vengurla-mochemad',  'sd-vengurla', 'Mochemad',    2),
  ('sd-vengurla-redi',      'sd-vengurla', 'Redi',        3),
  ('sd-vengurla-shiroda',   'sd-vengurla', 'Shiroda',     4),
  ('sd-vengurla-vengurla',  'sd-vengurla', 'Vengurla',    5);
