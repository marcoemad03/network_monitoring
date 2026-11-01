-- Inventory of the devices seen on the network (phones, PCs, printers...), the
-- notes people add to them, and how much each one used per day.

CREATE TABLE IF NOT EXISTS client_devices (
    organization_id UUID NOT NULL REFERENCES organizations(id),
    mac VARCHAR(17) NOT NULL,
    first_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_ip VARCHAR(45) NOT NULL DEFAULT '',
    hostname TEXT NOT NULL DEFAULT '',
    router_comment TEXT NOT NULL DEFAULT '',
    network_name TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (organization_id, mac)
);

CREATE INDEX IF NOT EXISTS idx_client_devices_seen ON client_devices(organization_id, last_seen DESC);

-- What a person told us about a device. Kept apart from client_devices so a
-- re-discovery can never overwrite it.
CREATE TABLE IF NOT EXISTS client_device_notes (
    organization_id UUID NOT NULL REFERENCES organizations(id),
    mac VARCHAR(17) NOT NULL,
    display_name TEXT NOT NULL DEFAULT '',
    note TEXT NOT NULL DEFAULT '',
    kind_override VARCHAR(20) NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (organization_id, mac)
);

CREATE TABLE IF NOT EXISTS client_usage_daily (
    organization_id UUID NOT NULL REFERENCES organizations(id),
    mac VARCHAR(17) NOT NULL,
    day DATE NOT NULL,
    download_bytes BIGINT NOT NULL DEFAULT 0,
    upload_bytes BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (organization_id, mac, day)
);

CREATE INDEX IF NOT EXISTS idx_client_usage_day ON client_usage_daily(organization_id, day);
