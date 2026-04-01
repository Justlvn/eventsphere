-- Participations aux événements : les utilisateurs enregistrent leur présence ;
-- seuls admin / responsables de l’asso organisatrice obtiennent le total via RPC (pas les noms).

create table if not exists public.event_participations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create index if not exists idx_event_participations_event_id
  on public.event_participations (event_id);

alter table public.event_participations enable row level security;

-- Chacun ne lit que sa propre ligne (savoir si je participe).
create policy "event_participations_select_own"
  on public.event_participations for select
  to authenticated
  using (auth.uid() = user_id);

-- S’inscrire : soi-même + événement visible (RLS sur events dans le EXISTS).
create policy "event_participations_insert_own"
  on public.event_participations for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.events e where e.id = event_id
    )
  );

-- Se désinscrire.
create policy "event_participations_delete_own"
  on public.event_participations for delete
  to authenticated
  using (auth.uid() = user_id);

-- Compteur pour organisateurs uniquement (aucune liste de user_id exposée en SELECT).
create or replace function public.event_participant_count(p_event_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  n integer;
  aid uuid;
  is_admin boolean;
  is_resp boolean;
begin
  select e.association_id into aid
  from public.events e
  where e.id = p_event_id;

  if aid is null then
    select exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'admin'
    ) into is_admin;
    if not is_admin then
      raise exception 'permission denied' using errcode = '42501';
    end if;
    select count(*)::integer into n
    from public.event_participations
    where event_id = p_event_id;
    return coalesce(n, 0);
  end if;

  select exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'admin'
  ) into is_admin;

  select exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid()
      and m.association_id = aid
      and m.role = 'responsible'
  ) into is_resp;

  if not is_admin and not is_resp then
    raise exception 'permission denied' using errcode = '42501';
  end if;

  select count(*)::integer into n
  from public.event_participations
  where event_id = p_event_id;

  return coalesce(n, 0);
end;
$$;

revoke all on function public.event_participant_count(uuid) from public;
grant execute on function public.event_participant_count(uuid) to authenticated;
