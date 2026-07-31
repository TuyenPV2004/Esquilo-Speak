create table course_versions (
  course_id varchar(100) not null references courses (id),
  version integer not null check (version > 0),
  state varchar(20) not null
    check (state in ('draft', 'review', 'approved', 'scheduled', 'published', 'retired')),
  source_language varchar(35) not null,
  target_language varchar(35) not null,
  locale varchar(35) not null,
  compatibility_version integer not null check (compatibility_version > 0),
  effective_at timestamptz,
  published_at timestamptz,
  retired_at timestamptz,
  content jsonb not null,
  owner_name varchar(200) not null,
  license_name varchar(200) not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  primary key (course_id, version)
);

create unique index course_versions_one_published_idx
  on course_versions (course_id)
  where state = 'published';

create index course_versions_scheduled_idx
  on course_versions (effective_at)
  where state = 'scheduled';

create table course_units (
  course_id varchar(100) not null,
  course_version integer not null,
  id varchar(100) not null,
  position integer not null check (position > 0),
  content jsonb not null,
  primary key (course_id, course_version, id),
  unique (course_id, course_version, position),
  foreign key (course_id, course_version)
    references course_versions (course_id, version) on delete cascade
);

alter table lessons
  drop constraint lessons_course_id_position_key;

alter table lessons
  add column course_version integer,
  add column unit_id varchar(100),
  add column locale varchar(35),
  add column compatibility_version integer,
  add column effective_at timestamptz,
  add column retired_at timestamptz,
  add column learner_content jsonb;

insert into course_versions (
  course_id, version, state, source_language, target_language, locale,
  compatibility_version, effective_at, published_at, content, owner_name,
  license_name, created_at, updated_at
)
select
  id,
  coalesce((payload #>> '{metadata,version}')::integer, 1),
  case when published then 'published' else 'draft' end,
  source_language,
  target_language,
  source_language,
  1,
  nullif(payload #>> '{metadata,publishedAt}', '')::timestamptz,
  nullif(payload #>> '{metadata,publishedAt}', '')::timestamptz,
  (payload - 'lessonIds' - 'metadata') || jsonb_build_object(
    'version', coalesce((payload #>> '{metadata,version}')::integer, 1),
    'locale', source_language,
    'unitIds', jsonb_build_array('unit-foundation'),
    'compatibilityVersion', 1,
    'owner', coalesce(payload #>> '{metadata,owner}', 'EsquiloSpeak content team'),
    'license', coalesce(payload #>> '{metadata,license}', 'Proprietary')
  ),
  coalesce(payload #>> '{metadata,owner}', 'EsquiloSpeak content team'),
  coalesce(payload #>> '{metadata,license}', 'Proprietary'),
  coalesce(nullif(payload #>> '{metadata,publishedAt}', '')::timestamptz, now()),
  now()
from courses;

insert into course_units (course_id, course_version, id, position, content)
select
  course_id,
  1,
  'unit-foundation',
  1,
  '{"id":"unit-foundation","title":{"vi":"Nền tảng","en":"Foundation"}}'::jsonb
from lessons
group by course_id;

update lessons
set course_version = version,
    unit_id = 'unit-foundation',
    locale = 'vi',
    compatibility_version = 1,
    effective_at = nullif(content #>> '{metadata,publishedAt}', '')::timestamptz,
    content = (content - 'metadata') || jsonb_build_object(
      'courseVersion', version,
      'unitId', 'unit-foundation',
      'locale', 'vi'
    ),
    learner_content = jsonb_set(
      (content - 'metadata') || jsonb_build_object(
        'courseVersion', version,
        'unitId', 'unit-foundation',
        'locale', 'vi'
      ),
      '{exercises}',
      coalesce((
        select jsonb_agg(exercise - 'correctOptionId' - 'correctAnswer' - 'explanation')
        from jsonb_array_elements(content->'exercises') exercise
      ), '[]'::jsonb)
    );

alter table lessons
  alter column course_version set not null,
  alter column unit_id set not null,
  alter column locale set not null,
  alter column compatibility_version set not null,
  alter column learner_content set not null,
  add constraint lessons_course_version_fk
    foreign key (course_id, course_version)
    references course_versions (course_id, version),
  add constraint lessons_unit_fk
    foreign key (course_id, course_version, unit_id)
    references course_units (course_id, course_version, id),
  add constraint lessons_course_version_position_key
    unique (course_id, course_version, position);

create table content_audit_events (
  id uuid primary key,
  course_id varchar(100) not null references courses (id),
  course_version integer not null,
  actor_subject_hash char(64) not null,
  action varchar(60) not null,
  occurred_at timestamptz not null,
  details jsonb not null default '{}'::jsonb
);

create index content_audit_events_course_idx
  on content_audit_events (course_id, course_version, occurred_at desc);
