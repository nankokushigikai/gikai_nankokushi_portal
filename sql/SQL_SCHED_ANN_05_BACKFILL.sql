-- ----------------------------------------------------------------------
-- 既存の「【日程決定】」お知らせを元の日程調整に紐づける
-- SQL_SCHED_ANN_04_DIAG_BACKFILL.sql で match_count = 1 だった行だけを更新する。
-- すでに紐づいている行(schedule_event_id が入っている行)は触らない。
-- 結果: 更新した行の一覧を返す(0行なら対象なし)
-- ----------------------------------------------------------------------
with matched as (
    select a.no, min(e.id) as event_id
    from public.announcements a
    join public.schedule_events e
      on a.title = '【日程決定】' || e.title
     and e.decided_slot_id is not null
     and exists (
           select 1 from public.schedule_slots s
            where s.id = e.decided_slot_id
              and s.slot_date = a.notice_date
         )
    where a.title like '【日程決定】%'
      and a.schedule_event_id is null
    group by a.no
    having count(e.id) = 1
)
update public.announcements a
   set schedule_event_id = m.event_id
  from matched m
 where a.no = m.no
returning a.no as announcement_no, a.title, a.notice_date, a.schedule_event_id;
