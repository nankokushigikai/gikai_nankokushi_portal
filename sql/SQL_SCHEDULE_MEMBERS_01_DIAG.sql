-- 日程調整：対象者全員表示の事前確認（読み取り専用・変更なし）
-- schedule_recipients / schedule_responses / member_directory の本番RLS定義を確認する
select
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('schedule_recipients', 'schedule_responses', 'member_directory')
order by tablename, cmd, policyname;
