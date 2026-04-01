-- Journal d’envoi des rappels push (évite les doublons si le cron tourne plusieurs fois).
create table if not exists public.event_push_reminders (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  reminder_kind text not null
    check (reminder_kind in (
      'day_before_visible',
      'participant_7d',
      'participant_3d'
    )),
  sent_at timestamptz not null default now(),
  unique (event_id, user_id, reminder_kind)
);

create index if not exists idx_event_push_reminders_event_kind
  on public.event_push_reminders (event_id, reminder_kind);

alter table public.event_push_reminders enable row level security;

-- Aucune policy : seul le service role (Edge Function) écrit ; les clients n’y accèdent pas.

-- Couples (événement, type de rappel) à traiter aujourd’hui (calendrier Europe/Paris).
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
  inner join public.event_participations ep on ep.event_id = e.id,
  bounds b
  where e.event_date is not null
    and (timezone('Europe/Paris', e.event_date))::date = b.d7
  union
  select distinct e.id, 'participant_3d'::text
  from public.events e
  inner join public.event_participations ep on ep.event_id = e.id,
  bounds b
  where e.event_date is not null
    and (timezone('Europe/Paris', e.event_date))::date = b.d3;
$$;

revoke all on function public.get_events_needing_reminders() from public;
grant execute on function public.get_events_needing_reminders() to service_role;
