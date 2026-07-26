CREATE TABLE IF NOT EXISTS device_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL UNIQUE REFERENCES devices(id) ON DELETE CASCADE,
    building VARCHAR(200) DEFAULT '',
    floor VARCHAR(200) DEFAULT '',
    room VARCHAR(200) DEFAULT '',
    connection_type VARCHAR(50) DEFAULT 'LAN',
    connected_interface VARCHAR(200) DEFAULT '',
    connected_ap VARCHAR(200) DEFAULT '',
    connected_switch VARCHAR(200) DEFAULT '',
    switch_port VARCHAR(100) DEFAULT '',
    dhcp_status VARCHAR(50) DEFAULT 'dynamic',
    lease_time_seconds INT DEFAULT 86400,
    signal_strength_dbm INT DEFAULT 0,
    current_download_speed BIGINT DEFAULT 0,
    current_upload_speed BIGINT DEFAULT 0,
    total_download_bytes BIGINT DEFAULT 0,
    total_upload_bytes BIGINT DEFAULT 0,
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    is_critical BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_di_device ON device_inventory(device_id);
CREATE INDEX idx_di_building ON device_inventory(building);
CREATE INDEX idx_di_floor ON device_inventory(floor);
CREATE INDEX idx_di_connection ON device_inventory(connection_type);

CREATE TABLE IF NOT EXISTS device_control_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    action VARCHAR(100) NOT NULL,
    action_detail TEXT DEFAULT '',
    performed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    result VARCHAR(50) NOT NULL DEFAULT 'success',
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_dcl_org ON device_control_logs(organization_id);
CREATE INDEX idx_dcl_device ON device_control_logs(device_id);
CREATE INDEX idx_dcl_action ON device_control_logs(action);
CREATE INDEX idx_dcl_created ON device_control_logs(created_at DESC);

CREATE TABLE IF NOT EXISTS device_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    event_data JSONB DEFAULT '{}',
    previous_value TEXT,
    new_value TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_de_org ON device_events(organization_id);
CREATE INDEX idx_de_device ON device_events(device_id);
CREATE INDEX idx_de_type ON device_events(event_type);
CREATE INDEX idx_de_created ON device_events(created_at DESC);

CREATE TABLE IF NOT EXISTS wifi_registration_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    ssid VARCHAR(200) DEFAULT '',
    bssid VARCHAR(50) DEFAULT '',
    signal_strength_dbm INT DEFAULT 0,
    frequency_mhz INT DEFAULT 0,
    channel INT DEFAULT 0,
    tx_rate_mbps DOUBLE PRECISION DEFAULT 0,
    rx_rate_mbps DOUBLE PRECISION DEFAULT 0,
    connected_ap VARCHAR(200) DEFAULT '',
    first_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_wrh_device ON wifi_registration_history(device_id);
CREATE INDEX idx_wrh_ap ON wifi_registration_history(connected_ap);

CREATE TABLE IF NOT EXISTS dhcp_lease_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    mac_address VARCHAR(50) NOT NULL,
    ip_address INET,
    hostname VARCHAR(200) DEFAULT '',
    lease_status VARCHAR(50) DEFAULT 'dynamic',
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_dlh_mac ON dhcp_lease_history(mac_address);
CREATE INDEX idx_dlh_ip ON dhcp_lease_history(ip_address);

CREATE TABLE IF NOT EXISTS mikrotik_sync_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    vendor_integration_id UUID NOT NULL REFERENCES vendor_integrations(id) ON DELETE CASCADE,
    last_dhcp_sync TIMESTAMPTZ,
    last_arp_sync TIMESTAMPTZ,
    last_wireless_sync TIMESTAMPTZ,
    last_bridge_sync TIMESTAMPTZ,
    last_interface_sync TIMESTAMPTZ,
    last_queue_sync TIMESTAMPTZ,
    last_firewall_sync TIMESTAMPTZ,
    last_dns_sync TIMESTAMPTZ,
    routeros_version VARCHAR(50) DEFAULT '',
    total_devices_synced INT DEFAULT 0,
    status VARCHAR(50) DEFAULT 'idle',
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_mss_org ON mikrotik_sync_state(organization_id);
CREATE INDEX idx_mss_vendor ON mikrotik_sync_state(vendor_integration_id);

ALTER TABLE devices ADD COLUMN IF NOT EXISTS building VARCHAR(200) DEFAULT '';
ALTER TABLE devices ADD COLUMN IF NOT EXISTS floor_name VARCHAR(200) DEFAULT '';
ALTER TABLE devices ADD COLUMN IF NOT EXISTS room VARCHAR(200) DEFAULT '';
ALTER TABLE devices ADD COLUMN IF NOT EXISTS connection_type VARCHAR(50) DEFAULT 'LAN';
ALTER TABLE devices ADD COLUMN IF NOT EXISTS connected_interface VARCHAR(200) DEFAULT '';
ALTER TABLE devices ADD COLUMN IF NOT EXISTS connected_ap VARCHAR(200) DEFAULT '';
ALTER TABLE devices ADD COLUMN IF NOT EXISTS connected_switch VARCHAR(200) DEFAULT '';
ALTER TABLE devices ADD COLUMN IF NOT EXISTS switch_port VARCHAR(100) DEFAULT '';
ALTER TABLE devices ADD COLUMN IF NOT EXISTS dhcp_status VARCHAR(50) DEFAULT 'dynamic';
ALTER TABLE devices ADD COLUMN IF NOT EXISTS lease_time_seconds INT DEFAULT 86400;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS signal_strength_dbm INT DEFAULT 0;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS current_download_speed BIGINT DEFAULT 0;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS current_upload_speed BIGINT DEFAULT 0;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS total_download_bytes BIGINT DEFAULT 0;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS total_upload_bytes BIGINT DEFAULT 0;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS is_critical BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS os_version VARCHAR(200) DEFAULT '';
