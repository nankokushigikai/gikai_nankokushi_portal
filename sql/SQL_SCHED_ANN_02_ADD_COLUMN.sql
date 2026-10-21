-- ----------------------------------------------------------------------
-- お知らせに「元になった日程調整」の番号を持たせる
-- ・日程調整の決定から作ったお知らせだけ値が入る(それ以外は null のまま)
-- ・日程調整が削除されたら null に戻す
-- ・列を足すだけなので、announcements の既存RLSはそのまま効く
-- 元に戻す: SQL_SCHED_ANN_06_ROLLBACK.sql
-- ----------------------------------------------------------------------
alter table public.announcements
    add column if not exists schedule_event_id bigint
    references public.schedule_events(id) on delete set null;

create index if not exists announcements_schedule_event_id_idx
    on public.announcements (schedule_event_id)
    where schedule_event_id is not null;

notify pgrst, 'reload schema';
