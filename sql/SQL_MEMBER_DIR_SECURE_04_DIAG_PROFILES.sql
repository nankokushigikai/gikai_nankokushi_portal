-- profiles の本番RLSと is_portal_admin() の本番定義を確認（読み取り専用）
-- profiles.role='admin' でも管理者判定されるため、本人が role を書き換えられないか確認する
select 'policy' as kind, policyname as name, cmd, roles::text as roles, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = 'profiles'
union all
select 'function', 'is_portal_admin', null, null, pg_get_functiondef('public.is_portal_admin()'::regprocedure), null
order by kind, name;
