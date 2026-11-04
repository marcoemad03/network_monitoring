-- The audit log records every part of the app, so a fixed list of areas and actions
-- rejected most entries.
ALTER TABLE audit_logs ALTER COLUMN action TYPE TEXT USING action::text;
ALTER TABLE audit_logs ALTER COLUMN entity_type TYPE TEXT USING entity_type::text;
