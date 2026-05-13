-- ============================================================
-- OurNative - Initial Database Schema
-- ============================================================

-- Enable required extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pg_trgm";

-- ============================================================
-- COMMUNITIES
-- ============================================================
create table public.communities (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  location      text,
  description   text,
  logo_url      text,
  is_private    boolean default true,
  created_by    uuid references auth.users(id) on delete set null,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- ============================================================
-- USER PROFILES
-- ============================================================
create table public.user_profiles (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users(id) on delete cascade,
  community_id        uuid references public.communities(id) on delete set null,
  full_name           text not null,
  surname             text,
  native_village      text,
  current_location    text,
  profile_photo_url   text,
  role                text not null default 'member'
                        check (role in ('member','elder','moderator','admin')),
  bio                 text,
  is_approved         boolean default false,
  language_pref       text default 'en',
  created_at          timestamptz default now(),
  updated_at          timestamptz default now(),
  unique(user_id)
);

-- ============================================================
-- POSTS (parent table for all content types)
-- ============================================================
create table public.posts (
  id              uuid primary key default gen_random_uuid(),
  community_id    uuid not null references public.communities(id) on delete cascade,
  author_id       uuid not null references public.user_profiles(id) on delete cascade,
  post_type       text not null
                    check (post_type in (
                      'memory','story','elder_wisdom','help_request',
                      'event','achievement','announcement'
                    )),
  title           text not null,
  body            text,
  cover_image_url text,
  status          text not null default 'pending_review'
                    check (status in (
                      'draft','pending_review','approved','rejected','hidden','reported'
                    )),
  visibility      text not null default 'community'
                    check (visibility in ('community','public','private')),
  comments_disabled boolean default false,
  is_pinned       boolean default false,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- Full-text search index on posts
create index posts_fts_idx on public.posts
  using gin(to_tsvector('english', coalesce(title,'') || ' ' || coalesce(body,'')));

-- ============================================================
-- MEMORIES
-- ============================================================
create table public.memories (
  id              uuid primary key default gen_random_uuid(),
  post_id         uuid not null references public.posts(id) on delete cascade,
  approx_year     text,
  location_name   text,
  people_names    text[],
  category        text check (category in (
                    'school_days','farming','festivals','weddings',
                    'village_roads','old_houses','temples','sports',
                    'local_shops','old_transport','family_memories','historical'
                  )),
  is_vintage      boolean default true,
  then_image_url  text,
  now_image_url   text,
  unique(post_id)
);

-- ============================================================
-- STORIES
-- ============================================================
create table public.stories (
  id              uuid primary key default gen_random_uuid(),
  post_id         uuid not null references public.posts(id) on delete cascade,
  story_period    text,
  audio_url       text,
  video_url       text,
  tags            text[],
  story_type      text check (story_type in (
                    'childhood','village_legend','family','struggle',
                    'migration','festival','moral','elder','inspirational'
                  )),
  unique(post_id)
);

-- ============================================================
-- ELDER WISDOM
-- ============================================================
create table public.elder_wisdom (
  id              uuid primary key default gen_random_uuid(),
  post_id         uuid not null references public.posts(id) on delete cascade,
  elder_name      text,
  elder_age       int,
  topic           text check (topic in (
                    'life_advice','conflict_resolution','farming_wisdom',
                    'family_values','honesty','hard_work','community_unity',
                    'old_traditions','village_history','other'
                  )),
  audio_url       text,
  video_url       text,
  transcript      text,
  unique(post_id)
);

-- ============================================================
-- HELP REQUESTS
-- ============================================================
create table public.help_requests (
  id              uuid primary key default gen_random_uuid(),
  post_id         uuid not null references public.posts(id) on delete cascade,
  help_type       text check (help_type in (
                    'blood','hospital','education','job_referral','emergency',
                    'funeral_support','lost_document','volunteer','financial','general'
                  )),
  urgency         text check (urgency in ('low','medium','high','critical')),
  contact_name    text,
  contact_phone   text,
  location        text,
  help_status     text default 'open'
                    check (help_status in ('open','in_progress','help_received','closed')),
  unique(post_id)
);

-- ============================================================
-- EVENTS
-- ============================================================
create table public.events (
  id              uuid primary key default gen_random_uuid(),
  community_id    uuid not null references public.communities(id) on delete cascade,
  post_id         uuid references public.posts(id) on delete set null,
  title           text not null,
  description     text,
  event_type      text check (event_type in (
                    'village_gathering','festival','sports','blood_donation',
                    'cleanliness_drive','tree_plantation','education',
                    'senior_citizen_meet','cultural','youth_meetup'
                  )),
  event_date      timestamptz not null,
  location        text,
  organizer_id    uuid references public.user_profiles(id) on delete set null,
  cover_image_url text,
  status          text default 'upcoming' check (status in ('upcoming','ongoing','completed','cancelled')),
  created_at      timestamptz default now()
);

-- ============================================================
-- EVENT RSVPS
-- ============================================================
create table public.event_rsvps (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  user_id     uuid not null references public.user_profiles(id) on delete cascade,
  status      text not null check (status in ('going','interested','not_going')),
  created_at  timestamptz default now(),
  unique(event_id, user_id)
);

-- ============================================================
-- COMMENTS
-- ============================================================
create table public.comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts(id) on delete cascade,
  author_id   uuid not null references public.user_profiles(id) on delete cascade,
  body        text not null,
  status      text default 'approved' check (status in ('approved','pending_review','hidden','reported')),
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- ============================================================
-- REACTIONS
-- ============================================================
create table public.reactions (
  id              uuid primary key default gen_random_uuid(),
  post_id         uuid not null references public.posts(id) on delete cascade,
  user_id         uuid not null references public.user_profiles(id) on delete cascade,
  reaction_type   text not null check (reaction_type in (
                    'respect','beautiful_memory','inspired','prayers','proud','thank_you'
                  )),
  created_at      timestamptz default now(),
  unique(post_id, user_id)
);

-- ============================================================
-- REPORTS
-- ============================================================
create table public.reports (
  id              uuid primary key default gen_random_uuid(),
  target_type     text not null check (target_type in ('post','comment','user')),
  target_id       uuid not null,
  reported_by     uuid not null references public.user_profiles(id) on delete cascade,
  reason          text not null check (reason in (
                    'political_content','hate_speech','personal_attack',
                    'fake_information','privacy_issue','spam','other'
                  )),
  details         text,
  status          text default 'pending' check (status in ('pending','reviewed','dismissed','actioned')),
  reviewed_by     uuid references public.user_profiles(id) on delete set null,
  created_at      timestamptz default now()
);

-- ============================================================
-- MEDIA FILES
-- ============================================================
create table public.media_files (
  id              uuid primary key default gen_random_uuid(),
  community_id    uuid references public.communities(id) on delete cascade,
  post_id         uuid references public.posts(id) on delete cascade,
  uploaded_by     uuid not null references public.user_profiles(id) on delete cascade,
  file_url        text not null,
  file_type       text check (file_type in ('image','audio','video','document')),
  caption         text,
  created_at      timestamptz default now()
);

-- ============================================================
-- MODERATION LOGS
-- ============================================================
create table public.moderation_logs (
  id              uuid primary key default gen_random_uuid(),
  moderator_id    uuid not null references public.user_profiles(id) on delete cascade,
  action          text not null check (action in (
                    'approved','rejected','hidden','warned','banned','unbanned'
                  )),
  target_type     text not null check (target_type in ('post','comment','user')),
  target_id       uuid not null,
  note            text,
  created_at      timestamptz default now()
);

-- ============================================================
-- UPDATED_AT TRIGGERS
-- ============================================================
create or replace function public.handle_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger on_communities_updated
  before update on public.communities
  for each row execute procedure public.handle_updated_at();

create trigger on_user_profiles_updated
  before update on public.user_profiles
  for each row execute procedure public.handle_updated_at();

create trigger on_posts_updated
  before update on public.posts
  for each row execute procedure public.handle_updated_at();

create trigger on_comments_updated
  before update on public.comments
  for each row execute procedure public.handle_updated_at();

-- ============================================================
-- AUTO-CREATE USER PROFILE ON SIGNUP
-- ============================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.user_profiles (user_id, full_name, is_approved)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    false
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.communities      enable row level security;
alter table public.user_profiles    enable row level security;
alter table public.posts            enable row level security;
alter table public.memories         enable row level security;
alter table public.stories          enable row level security;
alter table public.elder_wisdom     enable row level security;
alter table public.help_requests    enable row level security;
alter table public.events           enable row level security;
alter table public.event_rsvps      enable row level security;
alter table public.comments         enable row level security;
alter table public.reactions        enable row level security;
alter table public.reports          enable row level security;
alter table public.media_files      enable row level security;
alter table public.moderation_logs  enable row level security;

-- Helper: get current user's profile id
create or replace function public.current_profile_id()
returns uuid language sql stable as $$
  select id from public.user_profiles where user_id = auth.uid() limit 1;
$$;

-- Helper: get current user's role in community
create or replace function public.current_user_role(p_community_id uuid)
returns text language sql stable as $$
  select role from public.user_profiles
  where user_id = auth.uid() and community_id = p_community_id limit 1;
$$;

-- COMMUNITIES RLS
create policy "communities_select" on public.communities
  for select using (true);

create policy "communities_insert" on public.communities
  for insert with check (auth.uid() = created_by);

create policy "communities_update" on public.communities
  for update using (
    current_user_role(id) in ('admin')
  );

-- USER PROFILES RLS
create policy "profiles_select_own" on public.user_profiles
  for select using (true);

create policy "profiles_insert_own" on public.user_profiles
  for insert with check (auth.uid() = user_id);

create policy "profiles_update_own" on public.user_profiles
  for update using (auth.uid() = user_id);

-- POSTS RLS - approved posts visible to all in community
create policy "posts_select_approved" on public.posts
  for select using (
    status = 'approved'
    or author_id = public.current_profile_id()
    or public.current_user_role(community_id) in ('moderator','admin')
  );

create policy "posts_insert" on public.posts
  for insert with check (
    author_id = public.current_profile_id()
  );

create policy "posts_update_own" on public.posts
  for update using (
    author_id = public.current_profile_id()
    or public.current_user_role(community_id) in ('moderator','admin')
  );

-- MEMORIES RLS
create policy "memories_select" on public.memories
  for select using (
    exists (
      select 1 from public.posts p
      where p.id = post_id
        and (p.status = 'approved' or p.author_id = public.current_profile_id())
    )
  );

create policy "memories_insert" on public.memories
  for insert with check (
    exists (
      select 1 from public.posts p
      where p.id = post_id and p.author_id = public.current_profile_id()
    )
  );

-- STORIES RLS
create policy "stories_select" on public.stories
  for select using (
    exists (
      select 1 from public.posts p
      where p.id = post_id
        and (p.status = 'approved' or p.author_id = public.current_profile_id())
    )
  );

create policy "stories_insert" on public.stories
  for insert with check (
    exists (
      select 1 from public.posts p
      where p.id = post_id and p.author_id = public.current_profile_id()
    )
  );

-- ELDER WISDOM RLS
create policy "elder_wisdom_select" on public.elder_wisdom
  for select using (
    exists (
      select 1 from public.posts p
      where p.id = post_id
        and (p.status = 'approved' or p.author_id = public.current_profile_id())
    )
  );

create policy "elder_wisdom_insert" on public.elder_wisdom
  for insert with check (
    exists (
      select 1 from public.posts p
      where p.id = post_id and p.author_id = public.current_profile_id()
    )
  );

-- HELP REQUESTS RLS
create policy "help_requests_select" on public.help_requests
  for select using (
    exists (
      select 1 from public.posts p
      where p.id = post_id
        and (p.status = 'approved' or p.author_id = public.current_profile_id())
    )
  );

create policy "help_requests_insert" on public.help_requests
  for insert with check (
    exists (
      select 1 from public.posts p
      where p.id = post_id and p.author_id = public.current_profile_id()
    )
  );

-- EVENTS RLS
create policy "events_select" on public.events
  for select using (true);

create policy "events_insert" on public.events
  for insert with check (
    public.current_user_role(community_id) in ('admin','moderator')
    or organizer_id = public.current_profile_id()
  );

-- EVENT RSVPS RLS
create policy "rsvps_select" on public.event_rsvps
  for select using (true);

create policy "rsvps_insert_own" on public.event_rsvps
  for insert with check (user_id = public.current_profile_id());

create policy "rsvps_update_own" on public.event_rsvps
  for update using (user_id = public.current_profile_id());

-- COMMENTS RLS
create policy "comments_select" on public.comments
  for select using (status = 'approved' or author_id = public.current_profile_id());

create policy "comments_insert" on public.comments
  for insert with check (author_id = public.current_profile_id());

create policy "comments_update_own" on public.comments
  for update using (
    author_id = public.current_profile_id()
    or exists (
      select 1 from public.posts p
      join public.user_profiles up on up.community_id = p.community_id
      where p.id = post_id and up.user_id = auth.uid()
        and up.role in ('moderator','admin')
    )
  );

-- REACTIONS RLS
create policy "reactions_select" on public.reactions
  for select using (true);

create policy "reactions_insert_own" on public.reactions
  for insert with check (user_id = public.current_profile_id());

create policy "reactions_delete_own" on public.reactions
  for delete using (user_id = public.current_profile_id());

-- REPORTS RLS
create policy "reports_insert" on public.reports
  for insert with check (reported_by = public.current_profile_id());

create policy "reports_select_mod" on public.reports
  for select using (
    reported_by = public.current_profile_id()
    or exists (
      select 1 from public.user_profiles
      where user_id = auth.uid() and role in ('moderator','admin')
    )
  );

-- MEDIA FILES RLS
create policy "media_select_public" on public.media_files
  for select using (true);

create policy "media_insert_own" on public.media_files
  for insert with check (uploaded_by = public.current_profile_id());

-- MODERATION LOGS RLS
create policy "mod_logs_select" on public.moderation_logs
  for select using (
    exists (
      select 1 from public.user_profiles
      where user_id = auth.uid() and role in ('moderator','admin')
    )
  );

create policy "mod_logs_insert" on public.moderation_logs
  for insert with check (
    exists (
      select 1 from public.user_profiles
      where user_id = auth.uid() and role in ('moderator','admin')
    )
  );
