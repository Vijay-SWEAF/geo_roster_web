-- ============================================================
-- OurNative - Storage Buckets & Policies
-- ============================================================

-- Create storage buckets
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('profile-photos',   'profile-photos',   true,  5242880,   array['image/jpeg','image/png','image/webp']),
  ('post-images',      'post-images',       true,  10485760,  array['image/jpeg','image/png','image/webp','image/gif']),
  ('memory-archive',   'memory-archive',    true,  20971520,  array['image/jpeg','image/png','image/webp','image/gif']),
  ('story-audio',      'story-audio',       false, 52428800,  array['audio/mpeg','audio/mp4','audio/wav','audio/ogg']),
  ('elder-videos',     'elder-videos',      false, 524288000, array['video/mp4','video/quicktime','video/webm']),
  ('event-media',      'event-media',       true,  10485760,  array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

-- ============================================================
-- STORAGE POLICIES
-- ============================================================

-- profile-photos: public read, authenticated upload, owner delete
create policy "profile_photos_select" on storage.objects
  for select using (bucket_id = 'profile-photos');

create policy "profile_photos_insert" on storage.objects
  for insert with check (
    bucket_id = 'profile-photos'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "profile_photos_delete" on storage.objects
  for delete using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- post-images: public read, authenticated upload, owner/admin delete
create policy "post_images_select" on storage.objects
  for select using (bucket_id = 'post-images');

create policy "post_images_insert" on storage.objects
  for insert with check (
    bucket_id = 'post-images'
    and auth.role() = 'authenticated'
  );

create policy "post_images_delete" on storage.objects
  for delete using (
    bucket_id = 'post-images'
    and auth.role() = 'authenticated'
  );

-- memory-archive: public read, authenticated upload
create policy "memory_archive_select" on storage.objects
  for select using (bucket_id = 'memory-archive');

create policy "memory_archive_insert" on storage.objects
  for insert with check (
    bucket_id = 'memory-archive'
    and auth.role() = 'authenticated'
  );

-- story-audio: authenticated read, authenticated upload
create policy "story_audio_select" on storage.objects
  for select using (
    bucket_id = 'story-audio'
    and auth.role() = 'authenticated'
  );

create policy "story_audio_insert" on storage.objects
  for insert with check (
    bucket_id = 'story-audio'
    and auth.role() = 'authenticated'
  );

-- elder-videos: authenticated read, authenticated upload
create policy "elder_videos_select" on storage.objects
  for select using (
    bucket_id = 'elder-videos'
    and auth.role() = 'authenticated'
  );

create policy "elder_videos_insert" on storage.objects
  for insert with check (
    bucket_id = 'elder-videos'
    and auth.role() = 'authenticated'
  );

-- event-media: public read, admin/moderator upload
create policy "event_media_select" on storage.objects
  for select using (bucket_id = 'event-media');

create policy "event_media_insert" on storage.objects
  for insert with check (
    bucket_id = 'event-media'
    and auth.role() = 'authenticated'
  );
