-- Hospital NMS - Network Monitoring Schema
-- Device clients, traffic, ping, topology, real-time stats

-- WiFi / Wired Clients (computers, mobile, printers, etc.)
CREATE TABLE device_clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    mac_address MACADDR NOT NULL,
    ip_address INET,
    hostname VARCHAR(255),
    vendor VARCHAR(100),
    os_type VARCHAR(100),
    connection_type connection_type NOT NULL DEFAULT 'ethernet',
    ssid VARCHAR(100),
    bssid MACADDR,
    signal_strength_dbm INT,
    signal_quality_percent DECIMAL(5,2),
    channel INT,
    frequency_mhz INT,
    noise_dbm INT,
    snr_dbm INT,
    tx_rate_mbps DECIMAL(10,2),
    rx_rate_mbps DECIMAL(10,2),
    tx_bytes BIGINT DEFAULT 0,
    rx_bytes BIGINT DEFAULT 0,
    tx_packets BIGINT DEFAULT 0,
    rx_packets BIGINT DEFAULT 0,
    tx_errors BIGINT DEFAULT 0,
    rx_errors BIGINT DEFAULT 0,
    connected_ap_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    connected_switch_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    switch_port VARCHAR(50),
    vlan_id INT,
    lease_expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    first_seen TIMESTAMPTZ DEFAULT NOW(),
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Real-time traffic measurements (per interface)
CREATE TABLE device_traffic (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    interface_id UUID REFERENCES interfaces(id) ON DELETE CASCADE,
    upload_bps BIGINT NOT NULL DEFAULT 0,
    download_bps BIGINT NOT NULL DEFAULT 0,
    total_upload_bytes BIGINT NOT NULL DEFAULT 0,
    total_download_bytes BIGINT NOT NULL DEFAULT 0,
    upload_packets BIGINT DEFAULT 0,
    download_packets BIGINT DEFAULT 0,
    upload_errors BIGINT DEFAULT 0,
    download_errors BIGINT DEFAULT 0,
    upload_drops BIGINT DEFAULT 0,
    download_drops BIGINT DEFAULT 0,
    utilization_percent DECIMAL(5,2),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT create_hypertable('device_traffic', 'timestamp', chunk_time_interval => INTERVAL '1 hour');

-- Ping / Latency measurements
CREATE TABLE device_ping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    min_rtt_ms DECIMAL(10,2),
    max_rtt_ms DECIMAL(10,2),
    avg_rtt_ms DECIMAL(10,2),
    median_rtt_ms DECIMAL(10,2),
    stddev_rtt_ms DECIMAL(10,2),
    jitter_ms DECIMAL(10,2),
    packet_loss_percent DECIMAL(5,2) DEFAULT 0,
    packets_sent INT NOT NULL DEFAULT 5,
    packets_received INT NOT NULL DEFAULT 5,
    packets_lost INT NOT NULL DEFAULT 0,
    is_reachable BOOLEAN DEFAULT true,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT create_hypertable('device_ping', 'timestamp', chunk_time_interval => INTERVAL '1 hour');

-- Topology / Connection map
CREATE TABLE device_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    parent_device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    child_device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    parent_interface_id UUID REFERENCES interfaces(id) ON DELETE SET NULL,
    child_interface_id UUID REFERENCES interfaces(id) ON DELETE SET NULL,
    connection_type connection_type DEFAULT 'ethernet',
    medium VARCHAR(50) DEFAULT 'copper',
    speed_mbps DECIMAL(10,2),
    vlan_id INT,
    is_active BOOLEAN DEFAULT true,
    discovered_method VARCHAR(50) DEFAULT 'manual',
    discovered_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Uplink / Downlink speed tests
CREATE TABLE device_speed_tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    upload_speed_mbps DECIMAL(10,2),
    download_speed_mbps DECIMAL(10,2),
    latency_ms DECIMAL(10,2),
    jitter_ms DECIMAL(10,2),
    packet_loss_percent DECIMAL(5,2),
    test_server VARCHAR(255),
    test_duration_seconds INT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT create_hypertable('device_speed_tests', 'timestamp', chunk_time_interval => INTERVAL '1 day');

-- Enhance devices table with WiFi/SNMP credentials
ALTER TABLE devices ADD COLUMN IF NOT EXISTS snmp_community TEXT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS snmp_version VARCHAR(5);
ALTER TABLE devices ADD COLUMN IF NOT EXISTS snmp_port INT DEFAULT 161;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS ssh_port INT DEFAULT 22;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS ssh_username TEXT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS ssh_password TEXT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS api_endpoint TEXT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS api_token TEXT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS wifi_ssid TEXT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS wifi_channel INT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS wifi_frequency_mhz INT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS wifi_tx_power_dbm INT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS wifi_clients_count INT DEFAULT 0;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS signal_strength_dbm INT;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS signal_quality_percent DECIMAL(5,2);
ALTER TABLE devices ADD COLUMN IF NOT EXISTS noise_floor_dbm INT;

-- Indexes
CREATE INDEX idx_device_clients_mac ON device_clients(mac_address);
CREATE INDEX idx_device_clients_device ON device_clients(device_id);
CREATE INDEX idx_device_clients_active ON device_clients(is_active);
CREATE INDEX idx_device_clients_ap ON device_clients(connected_ap_id);
CREATE INDEX idx_device_clients_switch ON device_clients(connected_switch_id);
CREATE INDEX idx_device_clients_org ON device_clients(organization_id);

CREATE INDEX idx_device_traffic_device_time ON device_traffic(device_id, timestamp DESC);
CREATE INDEX idx_device_traffic_interface ON device_traffic(interface_id);

CREATE INDEX idx_device_ping_device_time ON device_ping(device_id, timestamp DESC);

CREATE INDEX idx_device_connections_parent ON device_connections(parent_device_id);
CREATE INDEX idx_device_connections_child ON device_connections(child_device_id);
CREATE INDEX idx_device_connections_active ON device_connections(is_active);

CREATE INDEX idx_device_speed_tests_device_time ON device_speed_tests(device_id, timestamp DESC);
