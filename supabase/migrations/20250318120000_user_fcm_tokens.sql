-- Tokens FCM par appareil (plusieurs lignes possibles par utilisateur).
create table if not exists public.user_fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null,
  platform text not null default 'android',
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

create index if not exists idx_user_fcm_tokens_user_id on public.user_fcm_tokens (user_id);

alter table public.user_fcm_tokens enable row level security;

create policy "user_fcm_tokens_select_own"
  on public.user_fcm_tokens for select
  using (auth.uid() = user_id);

create policy "user_fcm_tokens_insert_own"
  on public.user_fcm_tokens for insert
  with check (auth.uid() = user_id);

create policy "user_fcm_tokens_update_own"
  on public.user_fcm_tokens for update
  using (auth.uid() = user_id);

create policy "user_fcm_tokens_delete_own"
  on public.user_fcm_tokens for delete
  using (auth.uid() = user_id);
