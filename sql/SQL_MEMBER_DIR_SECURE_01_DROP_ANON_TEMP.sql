-- ----------------------------------------------------------------------
-- member_directory：未ログイン(anon)に全権限を与えていた一時ポリシーの削除
--
-- 本番で「*_anon_temp」(anon / 条件 true) の4本が残っており、
-- 未ログインの第三者が名簿の閲覧・追加・書換・削除をできる状態だった。
-- 自分のGoogleメールで「管理者・現職」行を追加すれば is_portal_admin() が true になり、
-- ポータル全体の管理者権限を奪える。
--
-- ポータル画面(auth.js含む)はすべてログイン後に名簿を読むため、削除しても動作に影響しない。
-- 影響があるのは scripts/backup-portal.ps1 の CSV 書き出し(anonキー使用)のみ。
-- ----------------------------------------------------------------------
drop policy if exists member_directory_select_anon_temp on public.member_directory;
drop policy if exists member_directory_insert_anon_temp on public.member_directory;
drop policy if exists member_directory_update_anon_temp on public.member_directory;
drop policy if exists member_directory_delete_anon_temp on public.member_directory;
