-- 日程調整：重複作成の確認（読み取り専用・変更なし）
-- 同じ作成者・同じタイトルの日程調整が複数ある組を一覧にする。
-- 各組の id・作成日時・日程候補数・回答数を並べるので、どれを残すかの判断材料にする。
select
    e.created_by_email,
    e.title,
    count(*) as 件数,
    string_agg(
        e.id::text
        || ' (' || to_char(e.created_at at time zone 'Asia/Tokyo', 'YYYY-MM-DD HH24:MI:SS')
        || ' / 候補' || (select count(*) from public.schedule_slots s where s.event_id = e.id)
        || ' / 回答' || (select count(*) from public.schedule_responses r
                          join public.schedule_slots s2 on s2.id = r.slot_id
                          where s2.event_id = e.id)
        || case when e.is_closed then ' / 締切済' else '' end
        || ')',
        ' , ' order by e.created_at
    ) as 明細
from public.schedule_events e
group by e.created_by_email, e.title
having count(*) > 1
order by max(e.created_at) desc;
