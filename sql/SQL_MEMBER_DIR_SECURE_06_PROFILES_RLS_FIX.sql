-- ----------------------------------------------------------------------
-- profiles：誰でも管理者になれる状態の是正
--
-- 本番の状態(2026/10/1 確認):
--   insert : 本人の行なら role を自由に指定して作成できる
--   update : auth.uid() is not null のみ = ログインすれば誰の行でも書換可
--   select : auth.uid() is not null のみ = 全員分のメール・権限が見える
-- is_portal_admin() は profiles.role='admin' でも true になるため、
-- 議員でない Google アカウントでも自分の profiles 行を admin にすれば管理者になれた。
--
-- 現行コードでの profiles の使われ方:
--   auth.js            : 自分の行を読むだけ
--   user-management.html(管理者専用): 全件読む・role を更新する
--   クライアントからの insert は無い
--
-- 是正後:
--   select : 自分の行 or 管理者
--   insert : 自分の行、かつ role は null か 'viewer' のみ
--   update : 管理者のみ
-- is_portal_admin() は SECURITY DEFINER のため、ここで使っても RLS の再帰は起きない。
-- ----------------------------------------------------------------------
drop policy if exists profiles_select_authenticated on public.profiles;
create policy profiles_select_own_or_admin on public.profiles
for select to authenticated
using (user_id = auth.uid() or public.is_portal_admin());

drop policy if exists profiles_insert_authenticated on public.profiles;
create policy profiles_insert_own_viewer on public.profiles
for insert to authenticated
with check (user_id = auth.uid() and coalesce(role, 'viewer') = 'viewer');

drop policy if exists profiles_update_authenticated on public.profiles;
create policy profiles_update_admin_only on public.profiles
for update to authenticated
using (public.is_portal_admin())
with check (public.is_portal_admin());
