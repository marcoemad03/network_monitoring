-- What the last inventory scan found out about each device.
CREATE TABLE IF NOT EXISTS asset_fingerprints (
    organization_id UUID NOT NULL REFERENCES organizations(id),
    device_key VARCHAR(64) NOT NULL, -- MAC address, or ip:<address> when there is none
    data JSONB NOT NULL,
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (organization_id, device_key)
);
