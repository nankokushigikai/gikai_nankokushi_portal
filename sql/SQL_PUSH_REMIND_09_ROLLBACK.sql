-- 取り消し用: 開始前通知(Push)を止めて、02〜08 で作ったものを消す(問題が出た場合のみ実行)
-- 通知を「止めるだけ」なら最初の1文だけ実行する。
select cron.unschedule('push-reminder-tick') where exists (select 1 from cron.job where jobname = 'push-reminder-tick');

-- 以下は完全に元へ戻す場合。画面(登録・編集画面の指定欄、トップの端末登録)を先に戻してから実行すること。
drop function if exists public.push_reminder_tick();
drop function if exists public.claim_push_reminders();
drop function if exists public.push_reminders_due();
drop function if exists public.register_push_subscription(text, text, text, text);
drop function if exists public.unregister_push_subscription(text);
drop table if exists public.push_reminder_sent;
drop table if exists public.push_subscriptions;
alter table public.announcements drop constraint if exists announcements_push_remind_minutes_check;
alter table public.announcements drop column if exists push_remind_minutes_1;
alter table public.announcements drop column if exists push_remind_minutes_2;
delete from vault.secrets where name = 'push_reminder_cron_secret';
notify pgrst, 'reload schema';
