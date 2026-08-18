-- general_question を個人アカウント単位に制限するためのRLS強化
-- 実行順序: 本SQLを Supabase SQL Editor で実行 -> 画面を再読み込み

-- 1) material: anon許可を廃止し、auth.uid()=account_id のみに統一
alter table public.general_question_material enable row level security;

drop policy if exists general_question_material_select_own on public.general_question_material;
create policy general_question_material_select_own on public.general_question_material
for select using (
    auth.uid() is not null and auth.uid() = account_id
);

drop policy if exists general_question_material_insert_authenticated on public.general_question_material;
create policy general_question_material_insert_authenticated on public.general_question_material
for insert with check (
    auth.uid() is not null and auth.uid() = account_id
);

drop policy if exists general_question_material_update_own on public.general_question_material;
create policy general_question_material_update_own on public.general_question_material
for update using (
    auth.uid() is not null and auth.uid() = account_id
) with check (
    auth.uid() is not null and auth.uid() = account_id
);

drop policy if exists general_question_material_delete_own on public.general_question_material;
create policy general_question_material_delete_own on public.general_question_material
for delete using (
    auth.uid() is not null and auth.uid() = account_id
);

-- 2) tracker: owner_account_id を追加し、本人データのみアクセス可
alter table public.general_question_tracker enable row level security;
alter table public.general_question_tracker add column if not exists owner_account_id uuid;
create index if not exists general_question_tracker_owner_idx on public.general_question_tracker(owner_account_id);

drop policy if exists general_question_tracker_select_authenticated on public.general_question_tracker;
create policy general_question_tracker_select_authenticated on public.general_question_tracker
for select using (
    auth.uid() is not null and owner_account_id = auth.uid()
);

drop policy if exists general_question_tracker_insert_authenticated on public.general_question_tracker;
create policy general_question_tracker_insert_authenticated on public.general_question_tracker
for insert with check (
    auth.uid() is not null and owner_account_id = auth.uid()
);

drop policy if exists general_question_tracker_update_authenticated on public.general_question_tracker;
create policy general_question_tracker_update_authenticated on public.general_question_tracker
for update using (
    auth.uid() is not null and owner_account_id = auth.uid()
) with check (
    auth.uid() is not null and owner_account_id = auth.uid()
);

drop policy if exists general_question_tracker_delete_authenticated on public.general_question_tracker;
create policy general_question_tracker_delete_authenticated on public.general_question_tracker
for delete using (
    auth.uid() is not null and owner_account_id = auth.uid()
);

-- 3) updates: 親トラッカーの所有者のみアクセス可
alter table public.general_question_updates enable row level security;

drop policy if exists general_question_updates_select_authenticated on public.general_question_updates;
create policy general_question_updates_select_authenticated on public.general_question_updates
for select using (
    auth.uid() is not null
    and exists (
        select 1
        from public.general_question_tracker t
        where t.id = general_question_updates.tracker_id
          and t.owner_account_id = auth.uid()
    )
);

drop policy if exists general_question_updates_insert_authenticated on public.general_question_updates;
create policy general_question_updates_insert_authenticated on public.general_question_updates
for insert with check (
    auth.uid() is not null
    and exists (
        select 1
        from public.general_question_tracker t
        where t.id = general_question_updates.tracker_id
          and t.owner_account_id = auth.uid()
    )
);

drop policy if exists general_question_updates_update_authenticated on public.general_question_updates;
create policy general_question_updates_update_authenticated on public.general_question_updates
for update using (
    auth.uid() is not null
    and exists (
        select 1
        from public.general_question_tracker t
        where t.id = general_question_updates.tracker_id
          and t.owner_account_id = auth.uid()
    )
) with check (
    auth.uid() is not null
    and exists (
        select 1
        from public.general_question_tracker t
        where t.id = general_question_updates.tracker_id
          and t.owner_account_id = auth.uid()
    )
);

drop policy if exists general_question_updates_delete_authenticated on public.general_question_updates;
create policy general_question_updates_delete_authenticated on public.general_question_updates
for delete using (
    auth.uid() is not null
    and exists (
        select 1
        from public.general_question_tracker t
        where t.id = general_question_updates.tracker_id
          and t.owner_account_id = auth.uid()
    )
);

-- PostgREST キャッシュ更新
notify pgrst, 'reload schema';
