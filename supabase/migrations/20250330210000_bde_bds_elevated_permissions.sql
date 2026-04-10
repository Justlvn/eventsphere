-- Responsables des associations BDE / BDS : mêmes droits que les admins globaux
-- pour les fonctions qui testaient uniquement users.role = 'admin'.

create or replace function public.is_elevated_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'admin'
  )
  or exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid()
      and m.role = 'responsible'
      and m.association_id in (
        '11d89d91-e233-480e-8e9d-48acf0675922'::uuid,
        '133610da-6a34-4b0b-a1bf-8b9dc9ce7919'::uuid
      )
  );
$$;

revoke all on function public.is_elevated_user() from public;
grant execute on function public.is_elevated_user() to authenticated;

-- Compteur participants : aligné sur is_elevated_user() au lieu du seul rôle admin.
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
    select public.is_elevated_user() into is_admin;
    if not is_admin then
      raise exception 'permission denied' using errcode = '42501';
    end if;
    select count(*)::integer into n
    from public.event_participations
    where event_id = p_event_id
      and status = 'going';
    return coalesce(n, 0);
  end if;

  select public.is_elevated_user() into is_admin;

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

-- Compteur « indisponibles » : mêmes droits.
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
    select public.is_elevated_user() into is_admin;
    if not is_admin then
      raise exception 'permission denied' using errcode = '42501';
    end if;
    select count(*)::integer into n
    from public.event_participations
    where event_id = p_event_id
      and status = 'unavailable';
    return coalesce(n, 0);
  end if;

  select public.is_elevated_user() into is_admin;

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

-- Si des policies RLS (hors repo) testent seulement `users.role = 'admin'`, les faire
-- utiliser `public.is_elevated_user()` pour que BDE/BDS aient les mêmes droits côté DB.
