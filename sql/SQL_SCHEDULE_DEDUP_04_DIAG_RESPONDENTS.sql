-- 日程調整：重複した「DXプロジェクトチーム　てすと」(id 18/19/20)の回答者の内訳（読み取り専用・変更なし）
-- 回答者ごとに、どの id に回答したかを並べる。
-- 「回答したのは18だけ」のような人がいるかを確認し、どれを残すかの判断材料にする。
select
    coalesce(max(r.member_name), r.member_email) as 回答者,
    r.member_email,
    string_agg(distinct s.event_id::text, ' , ' order by s.event_id::text) as 回答した日程調整id
from public.schedule_responses r
join public.schedule_slots s on s.id = r.slot_id
where s.event_id in (18, 19, 20)
group by r.member_email
order by 3, 1;
