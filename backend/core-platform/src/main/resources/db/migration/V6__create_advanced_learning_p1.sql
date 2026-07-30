create table advanced_feedback_results (
  id uuid primary key,
  learner_id uuid not null references learners (id),
  client_request_id uuid not null,
  request_hash char(64) not null,
  kind varchar(30) not null
    check (kind in ('pronunciation', 'writing', 'conversation')),
  content_ref varchar(160),
  input_text varchar(4000),
  transcript varchar(4000),
  score numeric(5, 2),
  feedback jsonb not null default '{}'::jsonb,
  provider varchar(60) not null,
  created_at timestamptz not null,
  unique (learner_id, client_request_id)
);

create index advanced_feedback_results_learner_idx
  on advanced_feedback_results (learner_id, created_at desc);

create table assessment_attempts (
  id uuid primary key,
  learner_id uuid not null references learners (id),
  client_attempt_id uuid not null,
  request_hash char(64) not null,
  level varchar(10) not null check (level in ('A1')),
  score integer not null check (score between 0 and 100),
  passed boolean not null,
  answer_summary jsonb not null,
  completed_at timestamptz not null,
  unique (learner_id, client_attempt_id)
);

create table completion_records (
  id uuid primary key,
  learner_id uuid not null references learners (id),
  assessment_attempt_id uuid not null unique references assessment_attempts (id),
  level varchar(10) not null check (level in ('A1')),
  record_type varchar(40) not null
    check (record_type in ('non_accredited_completion')),
  issued_at timestamptz not null
);

create table engagement_profiles (
  learner_id uuid primary key references learners (id),
  current_streak integer not null default 0 check (current_streak >= 0),
  longest_streak integer not null default 0 check (longest_streak >= 0),
  xp integer not null default 0 check (xp >= 0),
  last_learning_date date,
  updated_at timestamptz not null
);

create table engagement_events (
  id uuid primary key,
  learner_id uuid not null references learners (id),
  client_event_id uuid not null,
  event_type varchar(40) not null,
  xp_awarded integer not null check (xp_awarded between 0 and 1000),
  occurred_on date not null,
  created_at timestamptz not null,
  unique (learner_id, client_event_id)
);

create table learner_achievements (
  learner_id uuid not null references learners (id),
  code varchar(60) not null,
  earned_at timestamptz not null,
  primary key (learner_id, code)
);

create table notification_preferences (
  learner_id uuid primary key references learners (id),
  enabled boolean not null default false,
  reminder_time time,
  locale varchar(35) not null default 'vi',
  updated_at timestamptz not null
);

create table purchase_events (
  id uuid primary key,
  learner_id uuid not null references learners (id),
  purchase_token_hash char(64) not null,
  product_id varchar(120) not null,
  event_type varchar(30) not null
    check (event_type in ('purchase_verified', 'refund_verified')),
  provider_state varchar(30) not null
    check (provider_state in ('active', 'revoked')),
  occurred_at timestamptz not null,
  unique (purchase_token_hash, event_type)
);

create table entitlements (
  learner_id uuid not null references learners (id),
  code varchar(60) not null,
  status varchar(20) not null check (status in ('active', 'revoked', 'expired')),
  valid_until timestamptz,
  source varchar(30) not null,
  updated_at timestamptz not null,
  primary key (learner_id, code)
);

create table support_tickets (
  id uuid primary key,
  learner_id uuid not null references learners (id),
  ticket_type varchar(30) not null
    check (ticket_type in ('support', 'content_report')),
  content_ref varchar(160),
  locale varchar(35) not null,
  description varchar(2000) not null,
  status varchar(30) not null
    check (status in ('open', 'triaged', 'resolved', 'dismissed')),
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create index support_tickets_learner_idx
  on support_tickets (learner_id, created_at desc);
