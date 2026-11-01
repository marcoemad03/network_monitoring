-- Security scans: periodic snapshots of what the devices on the network are
-- talking to, taken from the router's connection table.
--
-- Only destinations are kept (a platform, a provider, an application or an
-- address), never page addresses or content, and rows older than the retention
-- window (SECURITY_RETENTION_DAYS) are deleted.

CREATE TABLE IF NOT EXISTS security_scans (
    id BIGSERIAL PRIMARY KEY,
    organization_id UUID NOT NULL REFERENCES organizations(id),
    taken_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    connections INT NOT NULL DEFAULT 0,
    devices INT NOT NULL DEFAULT 0,
    duration_ms INT NOT NULL DEFAULT 0,
    router_cpu_before INT NOT NULL DEFAULT 0,
    router_cpu_after INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_security_scans_org_time ON security_scans(organization_id, taken_at DESC);

-- What each device was connected to in a scan, grouped by destination label.
CREATE TABLE IF NOT EXISTS security_flow_stats (
    scan_id BIGINT NOT NULL REFERENCES security_scans(id) ON DELETE CASCADE,
    mac VARCHAR(17) NOT NULL DEFAULT '',
    ip VARCHAR(45) NOT NULL,
    label TEXT NOT NULL,
    label_kind VARCHAR(12) NOT NULL,
    bytes_down BIGINT NOT NULL DEFAULT 0,
    bytes_up BIGINT NOT NULL DEFAULT 0,
    connections INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_security_flow_scan ON security_flow_stats(scan_id);
CREATE INDEX IF NOT EXISTS idx_security_flow_mac ON security_flow_stats(mac, scan_id);

CREATE TABLE IF NOT EXISTS security_findings (
    id BIGSERIAL PRIMARY KEY,
    scan_id BIGINT NOT NULL REFERENCES security_scans(id) ON DELETE CASCADE,
    mac VARCHAR(17) NOT NULL DEFAULT '',
    ip VARCHAR(45) NOT NULL,
    severity VARCHAR(8) NOT NULL,
    code VARCHAR(40) NOT NULL,
    title TEXT NOT NULL,
    detail TEXT NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_security_findings_scan ON security_findings(scan_id);
