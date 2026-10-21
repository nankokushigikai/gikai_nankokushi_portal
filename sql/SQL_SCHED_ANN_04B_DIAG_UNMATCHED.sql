-- ----------------------------------------------------------------------
-- 【診断・読み取りのみ】04で照合0件だったお知らせ(98・82)の候補となる日程調整を探す
-- タイトルの一部一致 または 決定日程の日付一致 の日程調整を並べる(自動では紐づけない)
--   title_hit : 日程調整タイトルがお知らせタイトルに含まれる
--   date_hit  : 決定日程の日付がお知らせの日付と同じ
-- 1行も出なければ、元の日程調整は削除済み(または決定前)と考えられる
-- ----------------------------------------------------------------------
select a.no as announcement_no,
       a.title as announcement_title,
       a.notice_date,
       e.id as event_id,
       e.title as event_title,
       e.is_closed,
       s.slot_date as decided_date,
       position(e.title in a.title) > 0 as title_hit,
       s.slot_date = a.notice_date as date_hit
from public.announcements a
join public.schedule_events e on true
left join public.schedule_slots s on s.id = e.decided_slot_id
where a.no in (98, 82)
  and (position(e.title in a.title) > 0 or s.slot_date = a.notice_date)
order by a.no desc, e.id;
