-- ----------------------------------------------------------------------
-- ログイン中の利用者が「現職利用者(member_directory.is_current = true)」かを判定する
-- Googleアカウントさえあれば誰でもSupabaseの認証は通るため、
-- auth.uid() の有無だけでなく、名簿に登録された現職かどうかで判定する。
-- ----------------------------------------------------------------------
create or replace function public.is_current_portal_member()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        return false;
    end if;
    return exists (
        select 1
        from public.member_directory m
        where m.is_current = true
          and lower(trim(m.email)) = lower(trim(coalesce(auth.jwt()->>'email', '')))
          and coalesce(trim(m.email), '') <> ''
    );
end;
$$;

revoke all on function public.is_current_portal_member() from public;
revoke all on function public.is_current_portal_member() from anon;
grant execute on function public.is_current_portal_member() to authenticated;
grant execute on function public.is_current_portal_member() to service_role;
