create table engagement_event_policies (
  event_type varchar(40) not null,
  version integer not null check (version > 0),
  xp_awarded integer not null check (xp_awarded >= 0),
  enabled boolean not null default true,
  primary key (event_type, version)
);

create table engagement_achievement_policies (
  code varchar(100) primary key,
  trigger_type varchar(30) not null check (trigger_type in ('activity_count', 'streak')),
  threshold integer not null check (threshold > 0),
  enabled boolean not null default true
);

insert into engagement_achievement_policies (code, trigger_type, threshold)
values ('first-step', 'activity_count', 1),
       ('seven-day-streak', 'streak', 7);

insert into engagement_event_policies (event_type, version, xp_awarded)
values ('advanced_practice_completed', 1, 15),
       ('lesson_completed', 1, 25);

alter table engagement_events
  add column policy_version integer,
  add column evidence_ref varchar(160);

update engagement_events
set policy_version = 1
where event_type = 'advanced_practice_completed';

alter table notification_preferences
  add column timezone varchar(80) not null default 'UTC';
