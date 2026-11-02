-- Network map: names for the places on the network, and where each device was last seen.

-- A name for a router port ("ether3" -> "Emergency ward switch"). The router's own
-- interface comment is used when no name is set here.
CREATE TABLE IF NOT EXISTS network_places (
    organization_id UUID NOT NULL REFERENCES organizations(id),
    port_name VARCHAR(64) NOT NULL,
    label TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (organization_id, port_name)
);

-- Where a person says a device is ("Reception desk 2"). Overrides the port name.
ALTER TABLE client_device_notes ADD COLUMN IF NOT EXISTS place TEXT NOT NULL DEFAULT '';

-- The router port a device was last seen on, so offline devices keep their place.
ALTER TABLE client_devices ADD COLUMN IF NOT EXISTS last_port VARCHAR(64) NOT NULL DEFAULT '';
