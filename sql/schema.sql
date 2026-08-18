-- South Nankoku City Council political activity expense system schema
-- Includes: table definitions, constraints, indexes, RLS, and storage policies.

begin;

create extension if not exists pgcrypto;

-- ============================================================
-- Utility trigger for updated_at
-- ============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ============================================================
-- Master: user profiles
-- ============================================================
create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_user_profiles_updated_at
before update on public.user_profiles
for each row
execute function public.set_updated_at();

-- ============================================================
-- Activities (parent)
-- ============================================================
create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fiscal_year integer not null check (fiscal_year >= 2000 and fiscal_year <= 9999),
  receipt_number text,
  category_id smallint not null check (category_id between 1 and 8),
  start_date date not null,
  end_date date not null,
  destination text,
  location text,
  activity_details text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint activities_start_end_check check (end_date >= start_date),
  constraint activities_id_user_unique unique (id, user_id)
);

create index if not exists idx_activities_user_fiscal_year
  on public.activities(user_id, fiscal_year, start_date);

create trigger trg_activities_updated_at
before update on public.activities
for each row
execute function public.set_updated_at();

-- ============================================================
-- Expenses (many-to-one with activities)
-- ============================================================
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null,
  expense_type text not null check (expense_type in ('transportation', 'accommodation', 'per_diem', 'others')),
  route text,
  transport_method text,
  calculation_basis text,
  amount numeric(12,2) not null check (amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expenses_activity_fk
    foreign key (activity_id, user_id)
    references public.activities(id, user_id)
    on delete cascade
);

create index if not exists idx_expenses_user_activity
  on public.expenses(user_id, activity_id);

create trigger trg_expenses_updated_at
before update on public.expenses
for each row
execute function public.set_updated_at();

-- ============================================================
-- Receipts (one-to-one with activities)
-- ============================================================
create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null unique,
  payment_date date not null,
  payee text not null,
  title text not null,
  total_amount numeric(12,2) not null check (total_amount >= 0),
  apportion_ratio numeric(5,4) not null check (apportion_ratio >= 0.01 and apportion_ratio <= 1.0),
  reported_amount numeric(12,2) generated always as (round(total_amount * apportion_ratio, 2)) stored,
  has_receipt boolean not null,
  receipt_image_path text,
  no_receipt_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint receipts_activity_fk
    foreign key (activity_id, user_id)
    references public.activities(id, user_id)
    on delete cascade,
  constraint receipts_path_or_reason_check check (
    (has_receipt = true and receipt_image_path is not null and no_receipt_reason is null)
    or
    (has_receipt = false and receipt_image_path is null and no_receipt_reason is not null)
  )
);

create index if not exists idx_receipts_user_activity
  on public.receipts(user_id, activity_id);

create trigger trg_receipts_updated_at
before update on public.receipts
for each row
execute function public.set_updated_at();

-- ============================================================
-- Postages (form #5)
-- ============================================================
create table if not exists public.postages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null,
  item_type text not null check (item_type in ('stamp', 'postcard')),
  transaction_type text not null check (transaction_type in ('purchase', 'use')),
  transaction_date date not null,
  purpose text,
  quantity integer not null check (quantity > 0),
  price numeric(12,2) not null check (price >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint postages_activity_fk
    foreign key (activity_id, user_id)
    references public.activities(id, user_id)
    on delete cascade
);

create index if not exists idx_postages_user_activity
  on public.postages(user_id, activity_id, transaction_date);

create trigger trg_postages_updated_at
before update on public.postages
for each row
execute function public.set_updated_at();

-- ============================================================
-- Equipments (form #6)
-- ============================================================
create table if not exists public.equipments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null,
  equipment_name text not null,
  quantity integer not null check (quantity > 0),
  acquisition_date date not null,
  acquisition_price numeric(12,2) not null check (acquisition_price >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint equipments_activity_fk
    foreign key (activity_id, user_id)
    references public.activities(id, user_id)
    on delete cascade
);

create index if not exists idx_equipments_user_activity
  on public.equipments(user_id, activity_id, acquisition_date);

create trigger trg_equipments_updated_at
before update on public.equipments
for each row
execute function public.set_updated_at();

-- ============================================================
-- RLS enablement
-- ============================================================
alter table public.user_profiles enable row level security;
alter table public.activities enable row level security;
alter table public.expenses enable row level security;
alter table public.receipts enable row level security;
alter table public.postages enable row level security;
alter table public.equipments enable row level security;

-- user_profiles policies (id is user key)
drop policy if exists user_profiles_select_own on public.user_profiles;
create policy user_profiles_select_own on public.user_profiles
for select using (auth.uid() = id);

drop policy if exists user_profiles_insert_own on public.user_profiles;
create policy user_profiles_insert_own on public.user_profiles
for insert with check (auth.uid() = id);

drop policy if exists user_profiles_update_own on public.user_profiles;
create policy user_profiles_update_own on public.user_profiles
for update using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists user_profiles_delete_own on public.user_profiles;
create policy user_profiles_delete_own on public.user_profiles
for delete using (auth.uid() = id);

-- Reusable table policy pattern where user_id exists
-- Activities
drop policy if exists activities_select_own on public.activities;
create policy activities_select_own on public.activities
for select using (auth.uid() = user_id);

drop policy if exists activities_insert_own on public.activities;
create policy activities_insert_own on public.activities
for insert with check (auth.uid() = user_id);

drop policy if exists activities_update_own on public.activities;
create policy activities_update_own on public.activities
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists activities_delete_own on public.activities;
create policy activities_delete_own on public.activities
for delete using (auth.uid() = user_id);

-- Expenses
drop policy if exists expenses_select_own on public.expenses;
create policy expenses_select_own on public.expenses
for select using (auth.uid() = user_id);

drop policy if exists expenses_insert_own on public.expenses;
create policy expenses_insert_own on public.expenses
for insert with check (auth.uid() = user_id);

drop policy if exists expenses_update_own on public.expenses;
create policy expenses_update_own on public.expenses
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists expenses_delete_own on public.expenses;
create policy expenses_delete_own on public.expenses
for delete using (auth.uid() = user_id);

-- Receipts
drop policy if exists receipts_select_own on public.receipts;
create policy receipts_select_own on public.receipts
for select using (auth.uid() = user_id);

drop policy if exists receipts_insert_own on public.receipts;
create policy receipts_insert_own on public.receipts
for insert with check (auth.uid() = user_id);

drop policy if exists receipts_update_own on public.receipts;
create policy receipts_update_own on public.receipts
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists receipts_delete_own on public.receipts;
create policy receipts_delete_own on public.receipts
for delete using (auth.uid() = user_id);

-- Postages
drop policy if exists postages_select_own on public.postages;
create policy postages_select_own on public.postages
for select using (auth.uid() = user_id);

drop policy if exists postages_insert_own on public.postages;
create policy postages_insert_own on public.postages
for insert with check (auth.uid() = user_id);

drop policy if exists postages_update_own on public.postages;
create policy postages_update_own on public.postages
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists postages_delete_own on public.postages;
create policy postages_delete_own on public.postages
for delete using (auth.uid() = user_id);

-- Equipments
drop policy if exists equipments_select_own on public.equipments;
create policy equipments_select_own on public.equipments
for select using (auth.uid() = user_id);

drop policy if exists equipments_insert_own on public.equipments;
create policy equipments_insert_own on public.equipments
for insert with check (auth.uid() = user_id);

drop policy if exists equipments_update_own on public.equipments;
create policy equipments_update_own on public.equipments
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists equipments_delete_own on public.equipments;
create policy equipments_delete_own on public.equipments
for delete using (auth.uid() = user_id);

-- ============================================================
-- Storage: receipts bucket + user-scoped policies
-- ============================================================
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

-- Path convention: {user_id}/{filename}
-- Users can only access objects under their own folder.
drop policy if exists receipts_storage_select_own on storage.objects;
create policy receipts_storage_select_own on storage.objects
for select using (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists receipts_storage_insert_own on storage.objects;
create policy receipts_storage_insert_own on storage.objects
for insert with check (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists receipts_storage_update_own on storage.objects;
create policy receipts_storage_update_own on storage.objects
for update using (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists receipts_storage_delete_own on storage.objects;
create policy receipts_storage_delete_own on storage.objects
for delete using (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
);

commit;
