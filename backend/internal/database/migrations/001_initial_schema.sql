-- Hospital NMS - Initial Database Schema
-- PostgreSQL 16+ with TimescaleDB extension

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "timescaledb";

-- Enums
CREATE TYPE user_role AS ENUM ('admin', 'operator', 'viewer', 'auditor');
CREATE TYPE device_status AS ENUM ('online', 'offline', 'degraded', 'maintenance', 'unknown', 'unmanaged');
CREATE TYPE device_type AS ENUM ('router', 'switch', 'server', 'firewall', 'workstation', 'printer', 'access_point', 'camera', 'phone', 'iot', 'medical_device', 'unknown');
CREATE TYPE connection_type AS ENUM ('ethernet', 'wifi', 'fiber', 'cellular', 'satellite', 'vpn', 'virtual');
CREATE TYPE alert_severity AS ENUM ('critical', 'high', 'medium', 'low', 'info');
CREATE TYPE alert_status AS ENUM ('open', 'acknowledged', 'resolved', 'suppressed');
CREATE TYPE alert_category AS ENUM ('connectivity', 'performance', 'security', 'hardware', 'configuration', 'capacity', 'environmental', 'other');
CREATE TYPE scan_type AS ENUM ('arp', 'ping', 'port', 'snmp', 'topology', 'nmap');
CREATE TYPE scan_status AS ENUM ('pending', 'running', 'completed', 'failed', 'cancelled');
CREATE TYPE audit_action AS ENUM ('login', 'logout', 'create', 'update', 'delete', 'acknowledge', 'resolve', 'scan', 'export', 'configuration', 'permission_change', 'other');
CREATE TYPE audit_entity_type AS ENUM ('device', 'interface', 'alert', 'user', 'scan', 'configuration', 'system', 'report');

-- Organizations
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    code VARCHAR(20) UNIQUE NOT NULL,
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(200),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role user_role NOT NULL DEFAULT 'viewer',
    department VARCHAR(100),
    title VARCHAR(100),
    phone VARCHAR(50),
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    is_locked BOOLEAN DEFAULT false,
    is_mfa_enabled BOOLEAN DEFAULT false,
    mfa_secret VARCHAR(100),
    failed_login_attempts INT DEFAULT 0,
    locked_until TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    password_changed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Devices
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    name VARCHAR(200) NOT NULL,
    hostname VARCHAR(255),
    ip_address INET NOT NULL,
    mac_address MACADDR,
    device_type device_type NOT NULL DEFAULT 'unknown',
    status device_status NOT NULL DEFAULT 'unknown',
    vendor VARCHAR(100),
    model VARCHAR(100),
    serial_number VARCHAR(100),
    os_version VARCHAR(100),
    firmware_version VARCHAR(100),
    location VARCHAR(200),
    department VARCHAR(100),
    notes TEXT,
    custom_fields JSONB DEFAULT '{}',
    first_seen TIMESTAMPTZ DEFAULT NOW(),
    last_boot TIMESTAMPTZ,
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    is_critical BOOLEAN DEFAULT false,
    is_monitored BOOLEAN DEFAULT true,
    snmp_community TEXT,
    snmp_version VARCHAR(5),
    snmp_port INT DEFAULT 161,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Interfaces
CREATE TABLE interfaces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    mac_address MACADDR,
    ip_address INET,
    subnet_mask INET,
    gateway INET,
    dns_servers INET[],
    connection_type connection_type DEFAULT 'ethernet',
    is_up BOOLEAN DEFAULT false,
    is_management BOOLEAN DEFAULT false,
    mtu INT DEFAULT 1500,
    speed_mbps DECIMAL(10,2),
    duplex VARCHAR(10),
    media_type VARCHAR(50),
    index INT DEFAULT 0,
    vlan_id INT,
    switch_port VARCHAR(50),
    connected_device_id UUID REFERENCES devices(id),
    connected_interface_name VARCHAR(100),
    bytes_in BIGINT DEFAULT 0,
    bytes_out BIGINT DEFAULT 0,
    packets_in BIGINT DEFAULT 0,
    packets_out BIGINT DEFAULT 0,
    errors_in BIGINT DEFAULT 0,
    errors_out BIGINT DEFAULT 0,
    drops_in BIGINT DEFAULT 0,
    drops_out BIGINT DEFAULT 0,
    utilization_percent DECIMAL(5,2),
    last_status_change TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Device Metrics (TimescaleDB hypertable)
CREATE TABLE device_metrics (
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    cpu_usage_percent DECIMAL(5,2),
    memory_usage_percent DECIMAL(5,2),
    disk_usage_percent DECIMAL(5,2),
    temperature_celsius DECIMAL(5,2),
    uptime_seconds BIGINT,
    total_interfaces INT,
    up_interfaces INT,
    total_traffic_in_bps BIGINT,
    total_traffic_out_bps BIGINT,
    average_latency_ms DECIMAL(10,2),
    max_latency_ms DECIMAL(10,2),
    packet_loss_percent DECIMAL(5,2),
    total_alerts INT,
    critical_alerts INT,
    warning_alerts INT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT create_hypertable('device_metrics', 'timestamp', chunk_time_interval => INTERVAL '1 day');

-- Alerts
CREATE TABLE alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    severity alert_severity NOT NULL,
    status alert_status NOT NULL DEFAULT 'open',
    category alert_category NOT NULL DEFAULT 'other',
    device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    interface_id UUID REFERENCES interfaces(id) ON DELETE SET NULL,
    metric_name VARCHAR(100),
    metric_value DECIMAL(15,2),
    threshold_value DECIMAL(15,2),
    rule_id UUID,
    acknowledged_by UUID REFERENCES users(id),
    acknowledged_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    occurrence_count INT DEFAULT 1,
    is_suppressed BOOLEAN DEFAULT false,
    suppressed_until TIMESTAMPTZ,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Network Scans
CREATE TABLE network_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    type scan_type NOT NULL,
    status scan_status NOT NULL DEFAULT 'pending',
    name VARCHAR(200),
    target_subnet CIDR NOT NULL,
    target_ips INET[],
    port_range VARCHAR(50),
    ports INT[],
    initiated_by UUID REFERENCES users(id),
    total_hosts INT DEFAULT 0,
    discovered_hosts INT DEFAULT 0,
    active_hosts INT DEFAULT 0,
    duration_seconds INT,
    progress DECIMAL(5,2),
    error_message TEXT,
    result_summary TEXT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Scan Results
CREATE TABLE scan_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scan_id UUID NOT NULL REFERENCES network_scans(id) ON DELETE CASCADE,
    ip_address INET NOT NULL,
    hostname VARCHAR(255),
    mac_address MACADDR,
    vendor VARCHAR(100),
    open_ports INT[],
    os_guess VARCHAR(100),
    response_time_ms DECIMAL(10,2),
    is_alive BOOLEAN DEFAULT false,
    is_new_device BOOLEAN DEFAULT false,
    discovered_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit Logs
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    action audit_action NOT NULL,
    entity_type audit_entity_type NOT NULL,
    entity_id UUID,
    entity_name VARCHAR(200),
    performed_by UUID REFERENCES users(id),
    ip_address INET,
    user_agent TEXT,
    previous_values JSONB,
    new_values JSONB,
    description TEXT,
    is_success BOOLEAN DEFAULT true,
    failure_reason TEXT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Refresh Tokens
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_revoked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT
);

-- Indexes
CREATE INDEX idx_devices_org_status ON devices(organization_id, status);
CREATE INDEX idx_devices_ip ON devices(ip_address);
CREATE INDEX idx_devices_mac ON devices(mac_address);
CREATE INDEX idx_devices_type ON devices(device_type);
CREATE INDEX idx_devices_department ON devices(department);

CREATE INDEX idx_interfaces_device ON interfaces(device_id);
CREATE INDEX idx_interfaces_ip ON interfaces(ip_address);

CREATE INDEX idx_device_metrics_device_time ON device_metrics(device_id, timestamp DESC);

CREATE INDEX idx_alerts_status ON alerts(status);
CREATE INDEX idx_alerts_severity ON alerts(severity);
CREATE INDEX idx_alerts_device ON alerts(device_id);
CREATE INDEX idx_alerts_detected ON alerts(detected_at DESC);
CREATE INDEX idx_alerts_org_status ON alerts(organization_id, status);

CREATE INDEX idx_scans_org ON network_scans(organization_id);
CREATE INDEX idx_scans_status ON network_scans(status);
CREATE INDEX idx_scan_results_scan ON scan_results(scan_id);

CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp DESC);
CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_performer ON audit_logs(performed_by);
CREATE INDEX idx_audit_org_timestamp ON audit_logs(organization_id, timestamp DESC);

CREATE INDEX idx_refresh_token_hash ON refresh_tokens(token_hash);
CREATE INDEX idx_refresh_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_expires ON refresh_tokens(expires_at);

-- Updated At Trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_devices_updated_at
    BEFORE UPDATE ON devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_interfaces_updated_at
    BEFORE UPDATE ON interfaces
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_alerts_updated_at
    BEFORE UPDATE ON alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
