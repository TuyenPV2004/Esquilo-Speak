update lessons
set content = jsonb_set(
      content,
      '{advancedActivities}',
      '[{"id":"activity-basic-greetings","contentRef":"lesson-basic-greetings@1","mediaId":"a1-hello","expectedText":"Hello, my name is Ana.","targetLocale":"en","feedbackLocale":"vi"}]'::jsonb,
      true
    ),
    learner_content = jsonb_set(
      learner_content,
      '{advancedActivities}',
      '[{"id":"activity-basic-greetings","contentRef":"lesson-basic-greetings@1","mediaId":"a1-hello","expectedText":"Hello, my name is Ana.","targetLocale":"en","feedbackLocale":"vi"}]'::jsonb,
      true
    )
where id = 'lesson-basic-greetings'
  and version = 1;
