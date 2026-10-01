-- profiles で role='admin' になっている行の確認（読み取り専用）
-- 既に不正に管理者化された行が無いか、名簿(現職・管理者)と突き合わせる
select
    p.user_id,
    p.email,
    p.display_name,
    p.role,
    u.created_at        as auth_created_at,
    u.last_sign_in_at,
    m.full_name         as member_name,
    m.is_current,
    m.access_role
from public.profiles p
left join auth.users u on u.id = p.user_id
left join public.member_directory m
       on lower(trim(m.email)) = lower(trim(coalesce(p.email, u.email, '')))
where p.role = 'admin'
order by u.created_at;
