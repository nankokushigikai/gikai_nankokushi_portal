-- ----------------------------------------------------------------------
-- 【診断・読み取りのみ】開始前通知(Push)に必要な拡張機能が使えるかを確認する
--   pg_cron : 毎分の確認に使う
--   pg_net  : 送信関数(Edge Function)の呼び出しに使う
--   supabase_vault : 呼び出し用の秘密の値を保管する
-- installed_version が null なら「使えるが未有効」。行が無ければこのプロジェクトでは使えない。
-- ----------------------------------------------------------------------
select name, default_version, installed_version
from pg_available_extensions
where name in ('pg_cron', 'pg_net', 'supabase_vault')
order by name;
