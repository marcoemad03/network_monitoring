-- A device can be in several Marco groups; each group's blocks apply to it.
ALTER TABLE marco_group_members DROP CONSTRAINT IF EXISTS marco_group_members_device_id_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_mgm_group_device ON marco_group_members(group_id, device_id);
