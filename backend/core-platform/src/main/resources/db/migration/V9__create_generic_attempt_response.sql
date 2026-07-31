alter table attempts
  add column response jsonb;

update attempts
set response = jsonb_build_object(
  'kind', 'option',
  'optionId', selected_option_id
)
where response is null;

alter table attempts
  alter column response set not null,
  alter column selected_option_id drop not null;
