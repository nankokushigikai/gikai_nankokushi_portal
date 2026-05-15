-- ----------------------------------------------------------------------
-- document_tags テーブル（PDFタグ）
-- PDF資料に対してページ単位のタグメモを保存し、一覧から再オープンできるようにする。
-- ----------------------------------------------------------------------
create or replace function public.current_member_id()
returns text
language sql
stable
as $$
    select coalesce(
        nullif(current_setting('request.jwt.claim.member_id', true), ''),
        nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'member_id'), ''),
        nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), '')
    );
$$;

create table if not exists public.document_tags (
    id bigserial primary key,
    member_id text not null,
    session_id text not null,
    document_name text not null,
    document_label text not null default '',
    pdf_url text not null,
    page_number int not null check (page_number > 0),
    tag_text text not null,
    pos_x numeric(8,6),
    pos_y numeric(8,6),
    updated_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

alter table public.document_tags add column if not exists pos_x numeric(8,6);
alter table public.document_tags add column if not exists pos_y numeric(8,6);

alter table public.document_tags drop constraint if exists document_tags_pos_x_chk;
alter table public.document_tags add constraint document_tags_pos_x_chk
    check (pos_x is null or (pos_x >= 0 and pos_x <= 1));

alter table public.document_tags drop constraint if exists document_tags_pos_y_chk;
alter table public.document_tags add constraint document_tags_pos_y_chk
    check (pos_y is null or (pos_y >= 0 and pos_y <= 1));

create index if not exists document_tags_member_updated_idx
    on public.document_tags (member_id, updated_at desc);

create index if not exists document_tags_session_document_idx
    on public.document_tags (session_id, document_name, page_number);

alter table public.document_tags enable row level security;

-- document_tags ポリシー（本人のデータのみ操作可）
drop policy if exists document_tags_select_own on public.document_tags;
create policy document_tags_select_own on public.document_tags
for select using (
    member_id = public.current_member_id()
    or auth.role() = 'anon'
);

drop policy if exists document_tags_insert_own on public.document_tags;
create policy document_tags_insert_own on public.document_tags
for insert with check (
    member_id = public.current_member_id()
    or auth.role() = 'anon'
);

drop policy if exists document_tags_update_own on public.document_tags;
create policy document_tags_update_own on public.document_tags
for update using (
    member_id = public.current_member_id()
    or auth.role() = 'anon'
)
with check (
    member_id = public.current_member_id()
    or auth.role() = 'anon'
);

drop policy if exists document_tags_delete_own on public.document_tags;
create policy document_tags_delete_own on public.document_tags
for delete using (
    member_id = public.current_member_id()
    or auth.role() = 'anon'
);
