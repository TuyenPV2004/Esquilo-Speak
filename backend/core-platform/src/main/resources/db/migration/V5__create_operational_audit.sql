create table operational_audit_events (
  id uuid primary key,
  actor_hash char(64),
  action varchar(100) not null,
  outcome varchar(30) not null
    check (outcome in ('allowed', 'denied', 'rate_limited', 'failed')),
  trace_id varchar(64) not null,
  occurred_at timestamptz not null,
  metadata jsonb not null default '{}'::jsonb
);

create index operational_audit_events_time_idx
  on operational_audit_events (occurred_at desc);

create index operational_audit_events_action_idx
  on operational_audit_events (action, outcome, occurred_at desc);
