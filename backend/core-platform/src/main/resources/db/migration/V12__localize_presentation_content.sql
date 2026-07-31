alter table placement_assessments
  add column default_locale varchar(35) not null default 'en';

update placement_assessments
set default_locale = 'en',
    questions = '[
      {"id":"a1-greeting","prompt":{"en":"Choose the greeting.","vi":"Chọn lời chào."},"options":[{"id":"hello","text":{"en":"Hello","vi":"Xin chào"}},{"id":"later","text":{"en":"Later","vi":"Sau"}},{"id":"thanks","text":{"en":"Thanks","vi":"Cảm ơn"}}]},
      {"id":"a1-name","prompt":{"en":"Complete: My ___ is Ana.","vi":"Hoàn thành: My ___ is Ana."},"options":[{"id":"name","text":{"en":"name","vi":"tên"}},{"id":"day","text":{"en":"day","vi":"ngày"}},{"id":"food","text":{"en":"food","vi":"đồ ăn"}}]},
      {"id":"a1-number","prompt":{"en":"Choose the number three.","vi":"Chọn số ba."},"options":[{"id":"two","text":{"en":"two","vi":"hai"}},{"id":"three","text":{"en":"three","vi":"ba"}},{"id":"four","text":{"en":"four","vi":"bốn"}}]},
      {"id":"a1-goodbye","prompt":{"en":"Choose the farewell.","vi":"Chọn lời tạm biệt."},"options":[{"id":"goodbye","text":{"en":"Goodbye","vi":"Tạm biệt"}},{"id":"please","text":{"en":"Please","vi":"Làm ơn"}},{"id":"water","text":{"en":"Water","vi":"Nước"}}]}
    ]'::jsonb
where id = 'placement-en-vi-a1-v1';

create table learning_concepts (
  id varchar(100) primary key,
  default_locale varchar(35) not null,
  title jsonb not null
);

insert into learning_concepts (id, default_locale, title)
values (
  'concept-basic-greetings',
  'en',
  '{"en":"Basic greetings","vi":"Lời chào cơ bản"}'::jsonb
);

alter table engagement_achievement_policies
  add column title jsonb not null default '{}'::jsonb,
  add column description jsonb not null default '{}'::jsonb;

update engagement_achievement_policies
set title = case code
      when 'first-step' then '{"en":"First step","vi":"Bước đầu tiên"}'::jsonb
      when 'seven-day-streak' then '{"en":"Seven-day streak","vi":"Chuỗi bảy ngày"}'::jsonb
      else '{}'::jsonb
    end,
    description = case code
      when 'first-step' then '{"en":"Completed the first learning activity.","vi":"Đã hoàn thành hoạt động học đầu tiên."}'::jsonb
      when 'seven-day-streak' then '{"en":"Maintained a seven-day learning streak.","vi":"Đã duy trì chuỗi học bảy ngày."}'::jsonb
      else '{}'::jsonb
    end;
