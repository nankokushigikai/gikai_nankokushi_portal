-- ==================================================================
-- 補助金・助成金検索 (subsidies) テーブル
-- ==================================================================
-- 南国市が実施する事業者向け・住民向けの補助金/助成金を、ポータル内で
-- 検索・一覧できるようにするためのテーブル。
-- 閲覧: ログイン済みユーザー全員（下書きは管理者のみ）
-- 追加・編集・削除: 管理者のみ（public.is_portal_admin() を使用）
--
-- 実行方法: Supabase の SQL Editor に貼り付けて実行してください。

create table if not exists public.subsidies (
    id bigserial primary key,
    name text not null,
    audience text not null default 'both' check (audience in ('business', 'resident', 'both')),
    tags text[] not null default '{}',
    summary text,
    subsidy_amount text,
    application_status text not null default '募集中' check (application_status in ('募集中', '通年', '受付終了', '未定')),
    application_period text,
    contact_dept text,
    contact_info text,
    reference_url text,
    notes text,
    last_confirmed_on date,
    is_published boolean not null default false,
    created_by_email text,
    updated_by_email text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists subsidies_is_published_idx
on public.subsidies (is_published);

create index if not exists subsidies_audience_idx
on public.subsidies (audience);

create index if not exists subsidies_application_status_idx
on public.subsidies (application_status);

create index if not exists subsidies_tags_idx
on public.subsidies using gin (tags);

-- 管理者判定関数（supabase_setup.sql と同一定義。未作成の環境でも本ファイル単独で動くよう再定義）
create or replace function public.is_portal_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select
        auth.uid() is not null
        and (
            exists (
                select 1
                from public.profiles p
                where p.user_id = auth.uid()
                  and p.role = 'admin'
            )
            or exists (
                select 1
                from public.member_directory m
                where lower(trim(m.email)) = lower(trim(coalesce(auth.jwt()->>'email', '')))
                  and m.is_current = true
                  and m.access_role = '管理者'
            )
        );
$$;

revoke all on function public.is_portal_admin() from public;
grant execute on function public.is_portal_admin() to authenticated;
grant execute on function public.is_portal_admin() to service_role;

-- Row Level Security
alter table public.subsidies enable row level security;

-- テーブル作成時にSupabaseがanon/authenticatedへ自動付与する全権限を明示的に剥がし、
-- 必要最小限だけ再付与する（他プロジェクトでの事故を踏まえた既知の対策）。
revoke all on public.subsidies from anon, authenticated;
grant select, insert, update, delete on public.subsidies to authenticated;
grant usage, select on sequence public.subsidies_id_seq to authenticated;

-- SELECT: 公開済みは全ログインユーザーが閲覧可、下書きは管理者のみ
drop policy if exists subsidies_select_authenticated on public.subsidies;
create policy subsidies_select_authenticated on public.subsidies
for select to authenticated
using (
    is_published = true
    or public.is_portal_admin()
);

-- anon は明示的に閲覧不可（ポータル未ログインでは何も見えない）
drop policy if exists subsidies_select_anon on public.subsidies;
create policy subsidies_select_anon on public.subsidies
for select to anon
using (false);

-- INSERT / UPDATE / DELETE: 管理者のみ
drop policy if exists subsidies_insert_admin on public.subsidies;
create policy subsidies_insert_admin on public.subsidies
for insert to authenticated
with check (public.is_portal_admin());

drop policy if exists subsidies_update_admin on public.subsidies;
create policy subsidies_update_admin on public.subsidies
for update to authenticated
using (public.is_portal_admin())
with check (public.is_portal_admin());

drop policy if exists subsidies_delete_admin on public.subsidies;
create policy subsidies_delete_admin on public.subsidies
for delete to authenticated
using (public.is_portal_admin());
