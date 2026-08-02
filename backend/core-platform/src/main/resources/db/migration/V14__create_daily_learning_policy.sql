alter table engagement_event_policies
  add column counts_toward_streak boolean not null default true,
  add column requires_evidence boolean not null default false;

update engagement_event_policies
set requires_evidence = true
where event_type in ('lesson_completed', 'advanced_practice_completed');

insert into engagement_event_policies (
  event_type, version, xp_awarded, enabled, counts_toward_streak, requires_evidence
) values
  ('daily_session_started', 1, 0, true, false, false),
  ('daily_session_completed', 1, 0, true, false, false),
  ('daily_session_abandoned', 1, 0, true, false, false);

create unique index engagement_events_evidence_once_idx
  on engagement_events (learner_id, event_type, evidence_ref)
  where evidence_ref is not null
    and event_type in ('lesson_completed', 'advanced_practice_completed');

create table daily_learning_policies (
  version integer primary key check (version > 0),
  review_backlog_limit integer not null check (review_backlog_limit between 1 and 20),
  quick_practice_exercise_count integer not null
    check (quick_practice_exercise_count between 3 and 5),
  default_goal_type varchar(20) not null
    check (default_goal_type in ('minutes', 'lessons', 'reviews')),
  default_goal_target integer not null check (default_goal_target > 0),
  minutes_goal_min integer not null check (minutes_goal_min > 0),
  minutes_goal_max integer not null check (minutes_goal_max >= minutes_goal_min),
  lessons_goal_min integer not null check (lessons_goal_min > 0),
  lessons_goal_max integer not null check (lessons_goal_max >= lessons_goal_min),
  reviews_goal_min integer not null check (reviews_goal_min > 0),
  reviews_goal_max integer not null check (reviews_goal_max >= reviews_goal_min),
  quiet_hours_start time not null,
  quiet_hours_end time not null,
  enabled boolean not null default true
);

insert into daily_learning_policies (
  version, review_backlog_limit, quick_practice_exercise_count,
  default_goal_type, default_goal_target,
  minutes_goal_min, minutes_goal_max,
  lessons_goal_min, lessons_goal_max,
  reviews_goal_min, reviews_goal_max,
  quiet_hours_start, quiet_hours_end
) values (
  1, 5, 3,
  'minutes', 10,
  5, 60,
  1, 5,
  3, 30,
  '21:00:00', '07:00:00'
);
