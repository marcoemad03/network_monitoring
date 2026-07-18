CREATE TABLE web_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    device_id UUID REFERENCES devices(id),
    user_id UUID REFERENCES users(id),
    url TEXT NOT NULL,
    domain VARCHAR(500),
    category VARCHAR(100),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration_seconds INT DEFAULT 0,
    bytes_sent BIGINT DEFAULT 0,
    bytes_received BIGINT DEFAULT 0,
    is_blocked BOOLEAN DEFAULT false,
    blocked_by VARCHAR(50),
    is_encrypted BOOLEAN DEFAULT false,
    protocol VARCHAR(20) DEFAULT 'HTTPS',
    method VARCHAR(10) DEFAULT 'GET',
    content_type VARCHAR(200),
    status_code INT DEFAULT 200,
    user_agent TEXT,
    device_name VARCHAR(255),
    department VARCHAR(100)
);

CREATE TABLE connection_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    device_id UUID REFERENCES devices(id),
    user_id UUID REFERENCES users(id),
    protocol VARCHAR(20),
    source_ip VARCHAR(45) NOT NULL,
    dest_ip VARCHAR(45) NOT NULL,
    source_port INT,
    dest_port INT,
    bytes_sent BIGINT DEFAULT 0,
    bytes_received BIGINT DEFAULT 0,
    packets_sent INT DEFAULT 0,
    packets_received INT DEFAULT 0,
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    duration_seconds INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    application VARCHAR(100),
    department VARCHAR(100),
    device_name VARCHAR(255)
);

CREATE TABLE download_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    device_id UUID REFERENCES devices(id),
    user_id UUID REFERENCES users(id),
    filename VARCHAR(500) NOT NULL,
    url TEXT,
    size_bytes BIGINT DEFAULT 0,
    protocol VARCHAR(20) DEFAULT 'HTTPS',
    mime_type VARCHAR(100),
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    duration_seconds INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'in_progress',
    is_allowed BOOLEAN DEFAULT true,
    blocked_by VARCHAR(50),
    device_name VARCHAR(255),
    department VARCHAR(100)
);

CREATE TABLE report_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    report_type VARCHAR(10) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    data JSONB NOT NULL,
    total_websites INT DEFAULT 0,
    total_bandwidth_mb BIGINT DEFAULT 0,
    total_duration_minutes INT DEFAULT 0,
    unique_devices INT DEFAULT 0,
    unique_users INT DEFAULT 0,
    blocked_attempts INT DEFAULT 0,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(org_id, report_type, period_start, period_end)
);

CREATE TABLE report_exports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    report_type VARCHAR(10) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    format VARCHAR(10) NOT NULL,
    file_path TEXT,
    file_size_bytes INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending',
    generated_by UUID REFERENCES users(id),
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

CREATE TABLE alert_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    metric VARCHAR(100) NOT NULL,
    condition VARCHAR(20) NOT NULL,
    threshold DOUBLE PRECISION NOT NULL,
    duration_minutes INT DEFAULT 5,
    severity VARCHAR(20) DEFAULT 'warning',
    channels TEXT[] DEFAULT '{"in_app"}',
    is_active BOOLEAN DEFAULT true,
    notify_roles TEXT[],
    cooldown_minutes INT DEFAULT 60,
    last_triggered_at TIMESTAMPTZ,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE alert_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    rule_id UUID REFERENCES alert_rules(id),
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    severity VARCHAR(20) DEFAULT 'warning',
    metric_name VARCHAR(100),
    metric_value DOUBLE PRECISION,
    threshold DOUBLE PRECISION,
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by UUID REFERENCES users(id),
    is_read BOOLEAN DEFAULT false,
    channel VARCHAR(20) DEFAULT 'in_app'
);

CREATE TABLE dashboard_widgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    user_id UUID REFERENCES users(id),
    widget_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    config JSONB DEFAULT '{}',
    position INT DEFAULT 0,
    width INT DEFAULT 2,
    height INT DEFAULT 2,
    is_visible BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_web_logs_org_time ON web_logs(org_id, timestamp DESC);
CREATE INDEX idx_web_logs_device ON web_logs(org_id, device_id, timestamp DESC);
CREATE INDEX idx_web_logs_domain ON web_logs(org_id, domain);
CREATE INDEX idx_web_logs_blocked ON web_logs(org_id, is_blocked, timestamp DESC);
CREATE INDEX idx_conn_logs_active ON connection_logs(org_id, is_active, start_time DESC);
CREATE INDEX idx_conn_logs_device ON connection_logs(org_id, device_id, start_time DESC);
CREATE INDEX idx_dl_logs_org_time ON download_logs(org_id, start_time DESC);
CREATE INDEX idx_report_cache_type ON report_cache(org_id, report_type, period_start);
CREATE INDEX idx_alert_notifications_org ON alert_notifications(org_id, triggered_at DESC);
CREATE INDEX idx_dashboard_widgets_user ON dashboard_widgets(org_id, user_id, position);
