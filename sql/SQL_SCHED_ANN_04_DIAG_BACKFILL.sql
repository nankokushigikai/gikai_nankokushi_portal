-- ----------------------------------------------------------------------
-- 【診断・読み取りのみ】既存の「【日程決定】」お知らせと日程調整の照合結果を確認する
-- 照合条件: お知らせのタイトル = '【日程決定】' || 日程調整タイトル
--           かつ お知らせの日付 = 決定日程の日付
-- match_count = 1 の行だけを SQL_SCHED_ANN_05_BACKFILL.sql で紐づける。
-- match_count = 0 / 2以上 の行は自動では紐づけない(必要なら個別に判断)。
-- 前提: SQL_SCHED_ANN_02_ADD_COLUMN.sql を実行済みであること
-- ----------------------------------------------------------------------
select a.no as announcement_no,
       a.title,
       a.notice_date,
       a.schedule_event_id as current_link,
       count(e.id) as match_count,
       string_agg(e.id::text, ', ' order by e.id) as matched_event_ids
from public.announcements a
left join public.schedule_events e
       on a.title = '【日程決定】' || e.title
      and e.decided_slot_id is not null
      and exists (
            select 1 from public.schedule_slots s
             where s.id = e.decided_slot_id
               and s.slot_date = a.notice_date
          )
where a.title like '【日程決定】%'
group by a.no, a.title, a.notice_date, a.schedule_event_id
order by a.notice_date desc, a.no desc;
