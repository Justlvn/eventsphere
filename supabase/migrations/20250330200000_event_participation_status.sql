-- Statut de participation : « going » (je participe) ou « unavailable » (indisponible).

alter table public.event_participations
  add column status text not null default 'going'
  constraint event_participations_status_check check (status in ('going', 'unavailable'));

comment on column public.event_participations.status is
  'going = participe ; unavailable = indisponible (mutuellement exclusifs par ligne user+event).';

-- Upsert (changement de statut) = UPDATE sur conflit.
create policy "event_participations_update_own"
  on public.event_participations for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.events e where e.id = event_id
    )
  );

-- Compteur participants : uniquement « going ».
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
    where event_id = p_event_id
      and status = 'going';
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
  where event_id = p_event_id
    and status = 'going';

  return coalesce(n, 0);
end;
$$;

-- Compteur « indisponibles » (mêmes droits que le compteur participants).
create or replace function public.event_unavailable_count(p_event_id uuid)
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
    where event_id = p_event_id
      and status = 'unavailable';
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
  where event_id = p_event_id
    and status = 'unavailable';

  return coalesce(n, 0);
end;
$$;

revoke all on function public.event_unavailable_count(uuid) from public;
grant execute on function public.event_unavailable_count(uuid) to authenticated;

-- Rappels J-7 / J-3 : seulement les personnes ayant indiqué « je participe ».
create or replace function public.get_events_needing_reminders()
returns table (
  event_id uuid,
  reminder_kind text
)
language sql
stable
security definer
set search_path = public
as $$
  with d as (
    select
      (timezone('Europe/Paris', now()))::date as today_paris
  ),
  bounds as (
    select
      today_paris + 1 as d1,
      today_paris + 3 as d3,
      today_paris + 7 as d7
    from d
  )
  select distinct e.id, 'day_before_visible'::text
  from public.events e, bounds b
  where e.event_date is not null
    and (timezone('Europe/Paris', e.event_date))::date = b.d1
  union
  select distinct e.id, 'participant_7d'::text
  from public.events e
  inner join public.event_participations ep
    on ep.event_id = e.id
    and ep.status = 'going',
  bounds b
  where e.event_date is not null
    and (timezone('Europe/Paris', e.event_date))::date = b.d7
  union
  select distinct e.id, 'participant_3d'::text
  from public.events e
  inner join public.event_participations ep
    on ep.event_id = e.id
    and ep.status = 'going',
  bounds b
  where e.event_date is not null
    and (timezone('Europe/Paris', e.event_date))::date = b.d3;
$$;
