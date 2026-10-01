-- ----------------------------------------------------------------------
-- 【診断・読み取りのみ】お知らせ関連3表の現在のRLSポリシーを確認する
-- 実行前に、手元の supabase_setup.sql と本番が一致しているかを確認するため。
-- ----------------------------------------------------------------------
select tablename, policyname, permissive, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('announcements', 'announcement_recipients', 'announcement_attendance_responses')
order by tablename, cmd, policyname;
