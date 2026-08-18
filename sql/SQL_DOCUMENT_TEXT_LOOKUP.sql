-- ----------------------------------------------------------------------
-- document_text_lookup テーブル（PDF文字選択の関連情報辞書）
-- PDF上で選択した短い文字列に対する説明文・画像・参照URL・法令URLを保持する。
-- ----------------------------------------------------------------------
create table if not exists public.document_text_lookup (
    id bigserial primary key,
    member_id text,
    keyword text not null,
    title text not null default '',
    body text not null default '',
    image_url text,
    source_url text,
    law_url_1 text,
    law_url_2 text,
    law_url_3 text,
    updated_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

-- 既存テーブルへ差分適用
alter table public.document_text_lookup add column if not exists law_url_1 text;
alter table public.document_text_lookup add column if not exists law_url_2 text;
alter table public.document_text_lookup add column if not exists law_url_3 text;

-- タイトル未設定データを補完（タイトル=キーワード運用）
update public.document_text_lookup
set title = keyword
where coalesce(nullif(title, ''), '') = '';

create index if not exists document_text_lookup_keyword_idx
    on public.document_text_lookup (keyword);

create index if not exists document_text_lookup_updated_idx
    on public.document_text_lookup (updated_at desc);

alter table public.document_text_lookup enable row level security;

-- 閲覧は認証/匿名どちらも許可（ポータル運用に合わせる）
drop policy if exists document_text_lookup_select_all on public.document_text_lookup;
create policy document_text_lookup_select_all on public.document_text_lookup
for select using (
    auth.uid() is not null
    or auth.role() = 'anon'
);

-- 登録・更新・削除は認証または匿名運用を許可
drop policy if exists document_text_lookup_insert_policy on public.document_text_lookup;
create policy document_text_lookup_insert_policy on public.document_text_lookup
for insert with check (
    auth.uid() is not null
    or auth.role() = 'anon'
);

drop policy if exists document_text_lookup_update_policy on public.document_text_lookup;
create policy document_text_lookup_update_policy on public.document_text_lookup
for update using (
    auth.uid() is not null
    or auth.role() = 'anon'
)
with check (
    auth.uid() is not null
    or auth.role() = 'anon'
);

drop policy if exists document_text_lookup_delete_policy on public.document_text_lookup;
create policy document_text_lookup_delete_policy on public.document_text_lookup
for delete using (
    auth.uid() is not null
    or auth.role() = 'anon'
);
