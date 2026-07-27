CREATE TABLE IF NOT EXISTS telegram_configs (
    organization_id UUID PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
    bot_token TEXT NOT NULL DEFAULT '',
    chat_id TEXT NOT NULL DEFAULT '',
    grace_period_minutes INT NOT NULL DEFAULT 5 CHECK (grace_period_minutes >= 0),
    once_per_day BOOLEAN NOT NULL DEFAULT true,
    notify_connect BOOLEAN NOT NULL DEFAULT true,
    notify_disconnect BOOLEAN NOT NULL DEFAULT true,
    notify_new_device BOOLEAN NOT NULL DEFAULT true,
    notify_policy_violation BOOLEAN NOT NULL DEFAULT true,
    enabled BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS telegram_notification_history (
    id UUID PRIMARY KEY,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    device_mac VARCHAR(17) NOT NULL DEFAULT '',
    device_name VARCHAR(200) NOT NULL DEFAULT '',
    ip_address VARCHAR(45) NOT NULL DEFAULT '',
    access_point VARCHAR(100) NOT NULL DEFAULT '',
    event_type VARCHAR(30) NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    day_date DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE INDEX IF NOT EXISTS idx_telegram_history_org_event
    ON telegram_notification_history (organization_id, event_type, day_date, device_mac);
