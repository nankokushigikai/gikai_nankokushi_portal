-- 取り消し用: SQL_SCHED_ANN_02 / 03 / 05 を元に戻す(問題が出た場合のみ実行)
-- 列を削除するため、紐づけ(05の結果を含む)も消える。画面側を戻してから実行すること。
drop function if exists public.get_schedule_announcement_members(bigint);
drop index if exists public.announcements_schedule_event_id_idx;
alter table public.announcements drop column if exists schedule_event_id;
notify pgrst, 'reload schema';
