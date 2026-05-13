-- Make post comment counts reflect visible comments, not just approved ones.

create or replace function public.refresh_comment_count_for_post(p_post_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.posts
  set comment_count = (
    select count(*)
    from public.comments
    where post_id = p_post_id
      and status <> 'hidden'
  )
  where id = p_post_id;
end;
$$;
