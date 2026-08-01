alter table attempts
    add column evidence jsonb not null default '{}'::jsonb;

alter table attempts
    add constraint ck_attempts_evidence_object
    check (jsonb_typeof(evidence) = 'object');
