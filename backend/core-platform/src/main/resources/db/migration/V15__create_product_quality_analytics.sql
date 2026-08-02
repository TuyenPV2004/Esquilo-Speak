create view product_quality_attempt_facts as
select id, learner_id, course_id, lesson_id, lesson_version, exercise_id,
       correct, accepted_at, response_time_ms, evidence, session_id
from attempts;

create view product_quality_lesson_dimension as
select id, version, course_id, position, status, unit_id, content
from lessons;

create view product_quality_completion_facts as
select learner_id, course_id, lesson_id, lesson_version, active, completed_at
from learning_completions;

create view product_quality_session_facts as
select id, learner_id, course_id, state, completed_at
from learning_sessions;

create view product_quality_review_dimension as
select learner_id, concept_id, due_at
from review_schedules;

create view product_quality_mastery_dimension as
select learner_id, concept_id, score
from mastery_states;

create view product_quality_support_facts as
select id, ticket_type, content_ref, status, created_at
from support_tickets;

create view product_quality_engagement_facts as
select learner_id, event_type, occurred_on, created_at
from engagement_events;

create table analytics_retention_policies (
  policy_key varchar(60) not null,
  version integer not null check (version > 0),
  retention_days integer not null check (retention_days between 1 and 365),
  consent_purpose varchar(60) not null,
  enabled boolean not null default true,
  primary key (policy_key, version)
);

insert into analytics_retention_policies (
  policy_key, version, retention_days, consent_purpose, enabled
) values ('learning_product_analytics', 1, 30, 'operational_telemetry', true);

create table analytics_events (
  id uuid primary key,
  learner_id uuid not null references learners (id),
  client_event_id uuid not null,
  event_name varchar(60) not null check (event_name in (
    'learning_session_started', 'learning_session_completed', 'learning_session_abandoned',
    'lesson_started', 'lesson_completed', 'lesson_abandoned',
    'review_started', 'review_completed', 'review_abandoned',
    'practice_started', 'practice_completed', 'practice_abandoned',
    'exercise_presented', 'exercise_submitted', 'recommendation_presented',
    'recommendation_selected', 'feedback_helpfulness_recorded'
  )),
  event_version integer not null check (event_version = 1),
  occurred_at timestamptz not null,
  received_at timestamptz not null,
  course_id varchar(100),
  unit_id varchar(100),
  lesson_id varchar(100),
  lesson_version integer check (lesson_version is null or lesson_version > 0),
  exercise_id varchar(100),
  exercise_type varchar(60),
  session_kind varchar(40),
  attributes jsonb not null default '{}'::jsonb
    check (jsonb_typeof(attributes) = 'object'),
  expires_at timestamptz not null,
  unique (learner_id, client_event_id)
);

create index analytics_events_metric_idx
  on analytics_events (event_name, occurred_at, course_id);
create index analytics_events_content_idx
  on analytics_events (lesson_id, exercise_id, occurred_at);
create index analytics_events_expiry_idx on analytics_events (expires_at);

create table recommendation_policies (
  policy_key varchar(60) not null,
  version integer not null check (version > 0),
  weak_mastery_threshold numeric(6, 5) not null
    check (weak_mastery_threshold between 0 and 1),
  evaluation_dataset_version varchar(80) not null,
  rollback_version integer,
  enabled boolean not null default true,
  primary key (policy_key, version),
  check (rollback_version is null or rollback_version < version)
);

insert into recommendation_policies (
  policy_key, version, weak_mastery_threshold,
  evaluation_dataset_version, rollback_version, enabled
) values (
  'daily_next_learning', 1, 1.0,
  'recommendation-evaluation-v1', null, true
);

create table experiment_guardrail_policies (
  policy_key varchar(60) not null,
  version integer not null check (version > 0),
  primary_metric varchar(80) not null,
  guardrails jsonb not null check (jsonb_typeof(guardrails) = 'object'),
  minimum_sample_size integer not null check (minimum_sample_size > 0),
  enabled boolean not null default true,
  primary key (policy_key, version)
);

insert into experiment_guardrail_policies (
  policy_key, version, primary_metric, guardrails, minimum_sample_size, enabled
) values (
  'learning_outcome_experiment',
  1,
  'evidence_backed_session_completion',
  '{
    "firstLessonCompletionRelativeFloor": 0.98,
    "reviewCompletionRelativeFloor": 0.98,
    "contentReportRelativeCeiling": 1.05,
    "acknowledgedAttemptLossMaximum": 0,
    "privacyViolationMaximum": 0,
    "safetyIncidentMaximum": 0
  }'::jsonb,
  200,
  true
);

create table content_quality_items (
  id uuid primary key,
  source_type varchar(40) not null check (source_type in (
    'content_report', 'difficulty_anomaly', 'feedback_usefulness'
  )),
  source_ref varchar(200) not null,
  content_ref varchar(160) not null,
  course_id varchar(100),
  lesson_id varchar(100),
  exercise_id varchar(100),
  signal_code varchar(80) not null,
  evidence_count integer not null check (evidence_count > 0),
  observed_rate numeric(8, 5),
  priority varchar(20) not null check (priority in ('low', 'medium', 'high', 'critical')),
  status varchar(20) not null check (status in ('open', 'triaged', 'resolved', 'dismissed')),
  policy_version integer not null check (policy_version > 0),
  first_observed_at timestamptz not null,
  last_observed_at timestamptz not null,
  updated_at timestamptz not null,
  unique (source_type, source_ref)
);

create index content_quality_queue_idx
  on content_quality_items (status, priority, last_observed_at desc);
