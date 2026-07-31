create table proficiency_frameworks (
  code varchar(50) not null,
  version varchar(50) not null,
  applies_to_language varchar(35),
  title jsonb not null,
  source_uri varchar(500),
  created_at timestamptz not null,
  primary key (code, version)
);

create table proficiency_levels (
  framework_code varchar(50) not null,
  framework_version varchar(50) not null,
  code varchar(50) not null,
  ordinal integer not null check (ordinal > 0),
  title jsonb not null,
  descriptor jsonb not null default '{}'::jsonb,
  primary key (framework_code, framework_version, code),
  unique (framework_code, framework_version, ordinal),
  foreign key (framework_code, framework_version)
    references proficiency_frameworks (code, version)
);

insert into proficiency_frameworks (
  code, version, applies_to_language, title, source_uri, created_at
) values (
  'cefr',
  '2020',
  null,
  '{"vi":"Khung tham chiếu chung Châu Âu","en":"Common European Framework of Reference"}'::jsonb,
  'https://www.coe.int/en/web/common-european-framework-reference-languages/cefr-companion-volume-and-its-language-versions',
  now()
);

insert into proficiency_levels (
  framework_code, framework_version, code, ordinal, title
) values
  ('cefr', '2020', 'PRE_A1', 1, '{"vi":"Tiền A1","en":"Pre-A1"}'::jsonb),
  ('cefr', '2020', 'A1', 2, '{"vi":"A1","en":"A1"}'::jsonb),
  ('cefr', '2020', 'A2', 3, '{"vi":"A2","en":"A2"}'::jsonb),
  ('cefr', '2020', 'B1', 4, '{"vi":"B1","en":"B1"}'::jsonb),
  ('cefr', '2020', 'B2', 5, '{"vi":"B2","en":"B2"}'::jsonb),
  ('cefr', '2020', 'C1', 6, '{"vi":"C1","en":"C1"}'::jsonb),
  ('cefr', '2020', 'C2', 7, '{"vi":"C2","en":"C2"}'::jsonb);

alter table course_versions
  add column proficiency_framework_code varchar(50),
  add column proficiency_framework_version varchar(50),
  add column entry_level_code varchar(50),
  add column target_level_code varchar(50);

update course_versions
set proficiency_framework_code = 'cefr',
    proficiency_framework_version = '2020',
    entry_level_code = 'PRE_A1',
    target_level_code = 'A1',
    content = content || jsonb_build_object(
      'proficiency', jsonb_build_object(
        'frameworkCode', 'cefr',
        'frameworkVersion', '2020',
        'entryLevelCode', 'PRE_A1',
        'targetLevelCode', 'A1'
      )
    )
where target_language = 'en';

alter table course_versions
  alter column proficiency_framework_code set not null,
  alter column proficiency_framework_version set not null,
  alter column entry_level_code set not null,
  alter column target_level_code set not null,
  add constraint course_versions_entry_level_fk
    foreign key (
      proficiency_framework_code,
      proficiency_framework_version,
      entry_level_code
    ) references proficiency_levels (framework_code, framework_version, code),
  add constraint course_versions_target_level_fk
    foreign key (
      proficiency_framework_code,
      proficiency_framework_version,
      target_level_code
    ) references proficiency_levels (framework_code, framework_version, code);

create table placement_assessments (
  id varchar(100) primary key,
  course_id varchar(100) not null,
  course_version integer not null,
  framework_code varchar(50) not null,
  framework_version varchar(50) not null,
  level_code varchar(50) not null,
  pass_score integer not null check (pass_score between 0 and 100),
  questions jsonb not null,
  answer_key jsonb not null,
  active boolean not null default false,
  created_at timestamptz not null,
  foreign key (course_id, course_version)
    references course_versions (course_id, version),
  foreign key (framework_code, framework_version, level_code)
    references proficiency_levels (framework_code, framework_version, code)
);

create unique index placement_assessments_one_active_course_idx
  on placement_assessments (course_id)
  where active = true;

insert into placement_assessments (
  id, course_id, course_version, framework_code, framework_version,
  level_code, pass_score, questions, answer_key, active, created_at
) values (
  'placement-en-vi-a1-v1',
  'course-en-for-vi',
  1,
  'cefr',
  '2020',
  'A1',
  80,
  '[
    {"id":"a1-greeting","prompt":"Choose the greeting.","options":["hello","later","thanks"]},
    {"id":"a1-name","prompt":"Complete: My ___ is Ana.","options":["name","day","food"]},
    {"id":"a1-number","prompt":"Choose the number three.","options":["two","three","four"]},
    {"id":"a1-goodbye","prompt":"Choose the farewell.","options":["goodbye","please","water"]}
  ]'::jsonb,
  '["hello","name","three","goodbye"]'::jsonb,
  true,
  now()
);

alter table assessment_attempts
  drop constraint assessment_attempts_level_check;

alter table assessment_attempts
  rename column level to level_code;

alter table assessment_attempts
  alter column level_code type varchar(50),
  add column assessment_id varchar(100),
  add column framework_code varchar(50),
  add column framework_version varchar(50);

update assessment_attempts
set assessment_id = 'placement-en-vi-a1-v1',
    framework_code = 'cefr',
    framework_version = '2020';

alter table assessment_attempts
  alter column assessment_id set not null,
  alter column framework_code set not null,
  alter column framework_version set not null,
  add constraint assessment_attempts_assessment_fk
    foreign key (assessment_id) references placement_assessments (id),
  add constraint assessment_attempts_proficiency_level_fk
    foreign key (framework_code, framework_version, level_code)
      references proficiency_levels (framework_code, framework_version, code);

alter table completion_records
  drop constraint completion_records_level_check;

alter table completion_records
  rename column level to level_code;

alter table completion_records
  alter column level_code type varchar(50),
  add column framework_code varchar(50),
  add column framework_version varchar(50);

update completion_records
set framework_code = 'cefr',
    framework_version = '2020';

alter table completion_records
  alter column framework_code set not null,
  alter column framework_version set not null,
  add constraint completion_records_proficiency_level_fk
    foreign key (framework_code, framework_version, level_code)
      references proficiency_levels (framework_code, framework_version, code);
