-- ----------------------------------------------------------------------
-- C：議員でない認証ユーザーを締め出す対象表の洗い出し（読み取り専用）
--
-- public スキーマの全テーブルについて、次を1行ずつ出す:
--   rls_enabled        : RLS が有効か
--   loose_policies     : 「auth.uid() IS NOT NULL」だけ等、議員判定の無いポリシー名
--   member_restrictive : 既に議員/管理者判定の RESTRICTIVE ポリシーがあるか
--   all_policies       : 全ポリシー名(コマンド)
-- ----------------------------------------------------------------------
select
    c.relname as table_name,
    c.relrowsecurity as rls_enabled,
    string_agg(p.policyname || '(' || p.cmd || ')', ', ' order by p.policyname)
        filter (
            where p.permissive = 'PERMISSIVE'
              and 'anon' <> all(p.roles)
              and coalesce(p.qual, '') || coalesce(p.with_check, '') not like '%is_current_portal_member%'
              and coalesce(p.qual, '') || coalesce(p.with_check, '') not like '%is_portal_admin%'
              and coalesce(p.qual, '') || coalesce(p.with_check, '') not like '%auth.jwt()%'
        ) as loose_policies,
    bool_or(
        p.permissive = 'RESTRICTIVE'
        and (coalesce(p.qual, '') || coalesce(p.with_check, '')) like '%is_current_portal_member%'
    ) as member_restrictive,
    string_agg(p.policyname || '(' || p.cmd || ')', ', ' order by p.policyname) as all_policies
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_policies p on p.schemaname = n.nspname and p.tablename = c.relname
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
group by c.relname, c.relrowsecurity
order by c.relrowsecurity, c.relname;
