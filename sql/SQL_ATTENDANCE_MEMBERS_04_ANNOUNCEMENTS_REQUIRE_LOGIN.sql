-- ----------------------------------------------------------------------
-- お知らせ(announcements)を「ログインした現職利用者・管理者」だけが読めるようにする
--
-- 既存の announcements_select_all は visibility = 'all' だけを条件にしており、
-- 未ログイン(anon)でもAPI経由で読めてしまう。
-- 既存ポリシーは作り直さず、AS RESTRICTIVE で「ログイン必須」の条件を上乗せする。
-- (RESTRICTIVE は既存の許可ポリシーと AND で効く)
-- 前提: SQL_ATTENDANCE_MEMBERS_02_FN_IS_CURRENT_MEMBER.sql を先に実行済みであること
-- ----------------------------------------------------------------------
drop policy if exists announcements_select_require_member on public.announcements;
create policy announcements_select_require_member on public.announcements
as restrictive
for select
using (
    public.is_portal_admin()
    or public.is_current_portal_member()
);
