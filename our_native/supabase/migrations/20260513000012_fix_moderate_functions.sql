-- Fix: moderate_post and moderate_comment used raise_exception() which doesn't
-- exist in PostgreSQL. Replaced with proper IF/ELSIF/RAISE EXCEPTION syntax.

create or replace function public.moderate_post(
  p_post_id       uuid,
  p_action        text,  -- 'approve' | 'reject' | 'hide'
  p_note          text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  new_status text;
begin
  if p_action = 'approve' then
    new_status := 'approved';
  elsif p_action = 'reject' then
    new_status := 'rejected';
  elsif p_action = 'hide' then
    new_status := 'hidden';
  else
    raise exception 'Invalid action: %', p_action;
  end if;

  update public.posts
  set status          = new_status,
      moderation_note = p_note,
      updated_at      = now()
  where id = p_post_id;
end;
$$;

create or replace function public.moderate_comment(
  p_comment_id    uuid,
  p_action        text,  -- 'approve' | 'reject' | 'hide'
  p_note          text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  new_status text;
begin
  if p_action = 'approve' then
    new_status := 'approved';
  elsif p_action = 'reject' then
    new_status := 'hidden';
  elsif p_action = 'hide' then
    new_status := 'hidden';
  else
    raise exception 'Invalid action: %', p_action;
  end if;

  update public.comments
  set status          = new_status,
      moderation_note = p_note,
      updated_at      = now()
  where id = p_comment_id;
end;
$$;
