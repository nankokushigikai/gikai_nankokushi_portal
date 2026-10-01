-- ----------------------------------------------------------------------
-- 未ログイン(anon)でお知らせを読みに来た場合に、エラーではなく「0件」で返すための調整
--
-- 04 の RESTRICTIVE ポリシーは anon にも評価されるが、anon に関数の実行権限がないと
-- 「permission denied for function is_current_portal_member」というエラーになり、
-- 関数名が外部に見えてしまう。
-- この関数は未ログインなら必ず false を返し、情報は何も返さないため anon に実行権限を与えてよい。
-- (本番の is_portal_admin() も anon 実行可・false を返す運用になっている)
-- ----------------------------------------------------------------------
grant execute on function public.is_current_portal_member() to anon;
