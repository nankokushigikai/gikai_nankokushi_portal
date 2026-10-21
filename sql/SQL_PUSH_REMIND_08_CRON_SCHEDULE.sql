-- ----------------------------------------------------------------------
-- 開始前通知(Push)：毎分の確認を登録する(pg_cron)
-- 同じ名前のジョブがあれば置き換える。止めるときは SQL_PUSH_REMIND_09_ROLLBACK.sql の先頭だけ実行する。
-- 前提: 送信関数 push-reminder-send を deploy し、secrets を設定済みであること
-- 結果: 登録されたジョブが1行出れば成功
-- ----------------------------------------------------------------------
select cron.schedule('push-reminder-tick', '* * * * *', $$select public.push_reminder_tick()$$);

select jobid, jobname, schedule, command, active from cron.job where jobname = 'push-reminder-tick';
