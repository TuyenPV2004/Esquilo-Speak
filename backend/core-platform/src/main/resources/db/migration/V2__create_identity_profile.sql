create table learners (
  id uuid primary key,
  state varchar(30) not null
    check (state in ('active', 'restricted', 'merge_pending', 'merged', 'deletion_pending', 'deleted')),
  merged_into uuid references learners (id),
  created_at timestamptz not null,
  updated_at timestamptz not null,
  last_activity_at timestamptz not null,
  check ((state = 'merged') = (merged_into is not null))
);

create table identity_subjects (
  subject_hash char(64) primary key,
  issuer varchar(500) not null,
  learner_id uuid not null references learners (id),
  actor_type varchar(20) not null check (actor_type in ('guest', 'account')),
  created_at timestamptz not null,
  unique (learner_id, actor_type)
);

create index identity_subjects_learner_idx
  on identity_subjects (learner_id);

create table learner_profiles (
  learner_id uuid primary key references learners (id),
  ui_locale varchar(35) not null default 'vi',
  source_language varchar(35) not null default 'vi',
  target_language varchar(35) not null default 'en',
  age_band varchar(20)
    check (age_band is null or age_band in ('under_16', '16_17', 'adult')),
  learning_goal varchar(50),
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null
);

create table consent_records (
  id uuid primary key,
  learner_id uuid not null references learners (id),
  purpose varchar(50) not null
    check (purpose in ('required_service', 'operational_telemetry', 'marketing_notifications')),
  policy_version varchar(50) not null,
  granted boolean not null,
  recorded_at timestamptz not null
);

create index consent_records_current_idx
  on consent_records (learner_id, purpose, recorded_at desc);

create table identity_audit_events (
  id uuid primary key,
  learner_id uuid references learners (id),
  event_type varchar(80) not null,
  event_at timestamptz not null,
  metadata jsonb not null default '{}'::jsonb
);

create index identity_audit_events_learner_idx
  on identity_audit_events (learner_id, event_at desc);

create table guest_merge_tickets (
  id uuid primary key,
  guest_learner_id uuid not null references learners (id),
  secret_hash char(64) not null unique,
  expires_at timestamptz not null,
  consumed_at timestamptz
);

create table guest_merge_requests (
  idempotency_key uuid primary key,
  account_learner_id uuid not null references learners (id),
  guest_learner_id uuid not null references learners (id),
  ticket_id uuid not null references guest_merge_tickets (id),
  request_hash char(64) not null,
  merged_at timestamptz not null,
  unique (account_learner_id, guest_learner_id)
);

create table privacy_requests (
  id uuid primary key,
  learner_id uuid not null references learners (id),
  request_type varchar(20) not null check (request_type in ('export', 'deletion')),
  state varchar(30) not null check (state in ('requested', 'processing', 'completed', 'failed')),
  idempotency_key uuid not null,
  requested_at timestamptz not null,
  target_at timestamptz not null,
  completed_at timestamptz,
  artifact jsonb,
  artifact_expires_at timestamptz,
  failure_code varchar(80),
  unique (learner_id, request_type, idempotency_key)
);

create index privacy_requests_pending_idx
  on privacy_requests (state, requested_at)
  where state in ('requested', 'processing');
