alter table learner_profiles
  alter column ui_locale drop not null,
  alter column ui_locale drop default,
  alter column source_language drop not null,
  alter column source_language drop default,
  alter column target_language drop not null,
  alter column target_language drop default,
  add column active_course_id varchar(100) references courses (id),
  add constraint learner_profiles_language_pair_check check (
    (source_language is null and target_language is null)
    or
    (source_language is not null and target_language is not null
      and source_language <> target_language)
  );

update learner_profiles profile
set active_course_id = (
  select course.id
  from courses course
  where course.published = true
    and course.source_language = profile.source_language
    and course.target_language = profile.target_language
  order by course.id
  limit 1
)
where profile.active_course_id is null;

create index learner_profiles_active_course_idx
  on learner_profiles (active_course_id)
  where active_course_id is not null;
