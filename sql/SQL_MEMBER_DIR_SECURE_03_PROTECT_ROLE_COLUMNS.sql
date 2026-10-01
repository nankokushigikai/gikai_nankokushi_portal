-- ----------------------------------------------------------------------
-- member_directory：権限に関わる3項目を管理者以外が変更できないようにする
--
-- 本番の member_directory_update_admin_or_self は WITH CHECK が (is_portal_admin() OR true)
-- のため、本人が自分の行の access_role を「管理者」に書き換えられた。
-- is_portal_admin() は member_directory.access_role を見ているため、そのまま管理者権限になる。
--
-- 本人による氏名・住所等の更新(system-settings.html)は正規機能なので、ポリシーは変えず
-- トリガーで次の3項目だけを保護する:
--   access_role / is_current / member_id
--
-- ・ログイン利用者(authenticated)が管理者でない場合のみ拒否する。
-- ・SQL Editor(postgres)や service_role からの更新は対象外。
-- ----------------------------------------------------------------------
create or replace function public.member_directory_protect_role_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if current_user in ('authenticated', 'anon') and not public.is_portal_admin() then
        if new.access_role is distinct from old.access_role
           or new.is_current is distinct from old.is_current
           or new.member_id is distinct from old.member_id then
            raise exception '権限・在職状態・会員IDは管理者のみ変更できます。'
                using errcode = '42501';
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists member_directory_protect_role_columns on public.member_directory;
create trigger member_directory_protect_role_columns
before update on public.member_directory
for each row
execute function public.member_directory_protect_role_columns();
