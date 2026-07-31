create table learning_languages (
  id varchar(100) primary key,
  language_tag varchar(35) not null unique,
  enabled boolean not null,
  payload jsonb not null
);

create table courses (
  id varchar(100) primary key,
  source_language varchar(35) not null,
  target_language varchar(35) not null,
  published boolean not null,
  payload jsonb not null
);

create index courses_language_pair_idx
  on courses (source_language, target_language)
  where published = true;

create table lessons (
  id varchar(100) not null,
  version integer not null check (version > 0),
  course_id varchar(100) not null references courses (id),
  position integer not null check (position > 0),
  status varchar(30) not null,
  content jsonb not null,
  primary key (id, version),
  unique (course_id, position)
);

create table attempts (
  id uuid primary key,
  learner_id varchar(200) not null,
  client_attempt_id uuid not null,
  idempotency_key uuid not null,
  request_hash char(64) not null,
  course_id varchar(100) not null references courses (id),
  lesson_id varchar(100) not null,
  lesson_version integer not null,
  exercise_id varchar(100) not null,
  selected_option_id varchar(100) not null,
  correct boolean not null,
  occurred_at timestamptz not null,
  accepted_at timestamptz not null,
  response_time_ms integer check (response_time_ms is null or response_time_ms >= 0),
  foreign key (lesson_id, lesson_version) references lessons (id, version),
  unique (learner_id, client_attempt_id),
  unique (learner_id, idempotency_key)
);

create index attempts_progress_idx
  on attempts (learner_id, course_id, lesson_id, correct);

insert into learning_languages (id, language_tag, enabled, payload) values
  (
    'language-english',
    'en',
    true,
    '{"id":"language-english","languageTag":"en","name":{"vi":"Tiếng Anh","en":"English"},"enabled":true}'
  ),
  (
    'language-vietnamese',
    'vi',
    true,
    '{"id":"language-vietnamese","languageTag":"vi","name":{"vi":"Tiếng Việt","en":"Vietnamese"},"enabled":true}'
  );

insert into courses (id, source_language, target_language, published, payload) values
  (
    'course-en-for-vi',
    'vi',
    'en',
    true,
    '{
      "id":"course-en-for-vi",
      "sourceLanguage":"vi",
      "targetLanguage":"en",
      "title":{"vi":"Tiếng Anh căn bản","en":"Essential English"},
      "description":{"vi":"Bắt đầu giao tiếp tiếng Anh bằng các tình huống hằng ngày.","en":"Start communicating in English through everyday situations."},
      "lessonIds":["lesson-basic-greetings"],
      "metadata":{"version":1,"status":"published","owner":"EsquiloSpeak content team","license":"Proprietary","publishedAt":"2026-07-28T00:00:00Z"}
    }'
  );

insert into lessons (id, version, course_id, position, status, content) values
  (
    'lesson-basic-greetings',
    1,
    'course-en-for-vi',
    1,
    'published',
    '{
      "id":"lesson-basic-greetings",
      "courseId":"course-en-for-vi",
      "title":{"vi":"Lời chào cơ bản","en":"Basic greetings"},
      "objectives":[{"vi":"Nhận biết và sử dụng lời chào thông dụng.","en":"Recognize and use common greetings."}],
      "estimatedMinutes":5,
      "exercises":[{
        "id":"exercise-choose-hello",
        "type":"multiple_choice",
        "prompt":{"vi":"Từ nào có nghĩa là xin chào?","en":"Which word is a greeting?"},
        "options":[
          {"id":"option-hello","text":{"vi":"Hello","en":"Hello"}},
          {"id":"option-goodbye","text":{"vi":"Goodbye","en":"Goodbye"}}
        ],
        "correctOptionId":"option-hello",
        "explanation":{"vi":"Hello là lời chào thông dụng trong tiếng Anh.","en":"Hello is a common English greeting."},
        "skill":"vocabulary",
        "conceptIds":["concept-basic-greetings"]
      }],
      "metadata":{"version":1,"status":"published","owner":"EsquiloSpeak content team","license":"Proprietary","publishedAt":"2026-07-28T00:00:00Z"}
    }'
  );
