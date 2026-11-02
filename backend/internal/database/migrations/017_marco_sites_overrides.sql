-- Marco groups: per-device controls that work with or without a group, and the
-- websites that must keep working even when a group blocks something they share
-- an address with (for example Firebase and Translate share Google addresses with
-- YouTube's API).

-- Block a device or limit its speed. Keyed by MAC address because the address
-- changes with DHCP. Null limits mean "no limit set here".
CREATE TABLE IF NOT EXISTS marco_device_overrides (
    organization_id UUID NOT NULL REFERENCES organizations(id),
    mac VARCHAR(17) NOT NULL,
    blocked BOOLEAN NOT NULL DEFAULT FALSE,
    download_limit_mbps DOUBLE PRECISION,
    upload_limit_mbps DOUBLE PRECISION,
    reason TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (organization_id, mac)
);

-- Websites added by hand to the always-allowed list, on top of the built-in ones.
CREATE TABLE IF NOT EXISTS marco_allow_domains (
    organization_id UUID NOT NULL REFERENCES organizations(id),
    domain VARCHAR(253) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (organization_id, domain)
);
