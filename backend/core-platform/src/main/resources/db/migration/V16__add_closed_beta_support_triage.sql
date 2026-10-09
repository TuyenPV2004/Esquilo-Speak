alter table support_tickets
  add column severity varchar(2)
    check (severity in ('P0', 'P1', 'P2')),
  add column owner_ref varchar(120),
  add column action_plan varchar(2000),
  add column release_decision varchar(30)
    check (release_decision in (
      'pending', 'block', 'accept_with_plan', 'fixed', 'not_applicable'
    )),
  add column resolution_summary varchar(2000),
  add column closed_loop_at timestamptz;

create index support_tickets_beta_triage_idx
  on support_tickets (severity, status, updated_at desc);

create table support_ticket_triage_events (
  id uuid primary key,
  ticket_id uuid not null references support_tickets (id) on delete cascade,
  actor_hash char(64) not null,
  status varchar(30) not null
    check (status in ('triaged', 'resolved', 'dismissed')),
  severity varchar(2) not null
    check (severity in ('P0', 'P1', 'P2')),
  owner_ref varchar(120) not null,
  action_plan varchar(2000) not null,
  release_decision varchar(30) not null
    check (release_decision in (
      'pending', 'block', 'accept_with_plan', 'fixed', 'not_applicable'
    )),
  resolution_summary varchar(2000),
  closed_loop_confirmed boolean not null,
  occurred_at timestamptz not null
);

create index support_ticket_triage_events_ticket_idx
  on support_ticket_triage_events (ticket_id, occurred_at desc);
