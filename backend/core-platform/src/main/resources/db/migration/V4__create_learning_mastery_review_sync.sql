create table learning_sessions (
  id uuid primary key,
  learner_id varchar(200) not null,
  client_session_id uuid not null,
  idempotency_key uuid not null,
  request_hash char(64) not null,
  course_id varchar(100) not null references courses (id),
  content_version integer not null check (content_version > 0),
  state varchar(20) not null check (state in ('active', 'completed')),
  started_at timestamptz not null,
  completed_at timestamptz,
  unique (learner_id, client_session_id),
  unique (learner_id, idempotency_key)
);

alter table attempts
  add column session_id uuid references learning_sessions (id);

create table learning_completions (
  learner_id varchar(200) not null,
  course_id varchar(100) not null references courses (id),
  lesson_id varchar(100) not null,
  lesson_version integer not null,
  active boolean not null,
  completed_at timestamptz,
  updated_at timestamptz not null,
  primary key (learner_id, course_id, lesson_id)
);

create table mastery_evidence (
  id uuid primary key,
  learner_id varchar(200) not null,
  attempt_id uuid not null references attempts (id),
  concept_id varchar(100) not null,
  correct boolean not null,
  evidence_weight numeric(6, 4) not null check (evidence_weight > 0),
  model_version integer not null check (model_version > 0),
  occurred_at timestamptz not null,
  unique (attempt_id, concept_id)
);

create index mastery_evidence_learner_concept_idx
  on mastery_evidence (learner_id, concept_id, occurred_at);

create table mastery_states (
  learner_id varchar(200) not null,
  concept_id varchar(100) not null,
  model_version integer not null check (model_version > 0),
  score numeric(6, 5) not null check (score >= 0 and score <= 1),
  correct_evidence_count integer not null check (correct_evidence_count >= 0),
  evidence_count integer not null check (evidence_count > 0),
  last_evidence_at timestamptz not null,
  explanation jsonb not null,
  updated_at timestamptz not null,
  primary key (learner_id, concept_id)
);

create table review_schedules (
  learner_id varchar(200) not null,
  concept_id varchar(100) not null,
  model_version integer not null check (model_version > 0),
  due_at timestamptz not null,
  interval_days integer not null check (interval_days >= 0),
  ease_factor numeric(4, 2) not null check (ease_factor >= 1.30),
  repetitions integer not null check (repetitions >= 0),
  last_result varchar(20) not null check (last_result in ('correct', 'incorrect')),
  updated_at timestamptz not null,
  primary key (learner_id, concept_id)
);

create index review_schedules_due_idx
  on review_schedules (learner_id, due_at, concept_id);

create table sync_mutations (
  learner_id varchar(200) not null,
  client_mutation_id uuid not null,
  mutation_type varchar(50) not null,
  request_hash char(64) not null,
  state varchar(20) not null check (state in ('processing', 'applied')),
  result_payload jsonb,
  applied_at timestamptz,
  primary key (learner_id, client_mutation_id)
);

create table sync_changes (
  sequence_id bigserial primary key,
  learner_id varchar(200) not null,
  entity_type varchar(50) not null,
  entity_id varchar(200) not null,
  operation varchar(10) not null check (operation in ('upsert', 'delete')),
  payload jsonb not null,
  occurred_at timestamptz not null
);

create index sync_changes_pull_idx
  on sync_changes (learner_id, sequence_id);
