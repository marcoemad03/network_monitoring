CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_org_mac_unique
    ON devices (organization_id, mac_address)
    WHERE mac_address IS NOT NULL;
