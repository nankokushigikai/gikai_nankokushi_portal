-- 南国市条例リンク管理テーブル
-- 実行後、nankoku-ordinances.html で DB からタイル表示されます。

create table if not exists public.nankoku_ordinance_links (
    id bigserial primary key,
    title text not null,
    link_url text not null,
    display_order integer not null default 100,
    is_active boolean not null default true,
    created_by_email text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint nankoku_ordinance_links_display_order_check check (display_order > 0),
    constraint nankoku_ordinance_links_url_check check (link_url ~* '^https?://')
);

create index if not exists nankoku_ordinance_links_active_order_idx
on public.nankoku_ordinance_links (is_active, display_order, title);

alter table public.nankoku_ordinance_links enable row level security;

drop policy if exists nankoku_ordinance_links_select_authenticated on public.nankoku_ordinance_links;
create policy nankoku_ordinance_links_select_authenticated on public.nankoku_ordinance_links
for select using (auth.uid() is not null);

drop policy if exists nankoku_ordinance_links_insert_admin on public.nankoku_ordinance_links;
create policy nankoku_ordinance_links_insert_admin on public.nankoku_ordinance_links
for insert with check (
    auth.uid() is not null
    and exists (
        select 1
        from public.member_directory m
        where lower(trim(m.email)) = lower(trim(coalesce(auth.jwt()->>'email', '')))
          and m.is_current = true
          and m.access_role = '管理者'
    )
);

drop policy if exists nankoku_ordinance_links_update_admin on public.nankoku_ordinance_links;
create policy nankoku_ordinance_links_update_admin on public.nankoku_ordinance_links
for update using (
    auth.uid() is not null
    and exists (
        select 1
        from public.member_directory m
        where lower(trim(m.email)) = lower(trim(coalesce(auth.jwt()->>'email', '')))
          and m.is_current = true
          and m.access_role = '管理者'
    )
)
with check (
    auth.uid() is not null
    and exists (
        select 1
        from public.member_directory m
        where lower(trim(m.email)) = lower(trim(coalesce(auth.jwt()->>'email', '')))
          and m.is_current = true
          and m.access_role = '管理者'
    )
);

drop policy if exists nankoku_ordinance_links_delete_admin on public.nankoku_ordinance_links;
create policy nankoku_ordinance_links_delete_admin on public.nankoku_ordinance_links
for delete using (
    auth.uid() is not null
    and exists (
        select 1
        from public.member_directory m
        where lower(trim(m.email)) = lower(trim(coalesce(auth.jwt()->>'email', '')))
          and m.is_current = true
          and m.access_role = '管理者'
    )
);

insert into public.nankoku_ordinance_links (title, link_url, display_order, is_active)
select * from (values
    ('南国市議会基本条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000454.html', 10, true),
    ('南国市個人情報保護条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000015.html', 20, true),
    ('南国市文書管理条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000412.html', 30, true),
    ('南国市議会委員会条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000003.html', 40, true),
    ('南国市職員給与条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000040.html', 50, true),
    ('南国市都市計画条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000287.html', 60, true),
    ('南国市情報公開条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000014.html', 70, true),
    ('南国市行政手続条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000013.html', 80, true),
    ('南国市財政状況の公表に関する条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000063.html', 90, true),
    ('南国市職員定数条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000030.html', 100, true),
    ('南国市税条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000078.html', 110, true),
    ('南国市防災会議条例', 'https://www1.g-reiki.net/nankoku/reiki_honbun/r291RG00000331.html', 120, true)
) as seed(title, link_url, display_order, is_active)
where not exists (
    select 1
    from public.nankoku_ordinance_links existing
    where existing.title = seed.title
      and existing.link_url = seed.link_url
);
