-- Marco Groups policy engine.
-- Dedicated tables so the feature does not interfere with the legacy asset grouping.

CREATE TABLE IF NOT EXISTS marco_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    color VARCHAR(50) NOT NULL DEFAULT 'blue',
    icon VARCHAR(50) NOT NULL DEFAULT 'group',
    policy JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marco_groups_org ON marco_groups(organization_id);

-- A device belongs to AT MOST one Marco group (enforced by UNIQUE(device_id)).
CREATE TABLE IF NOT EXISTS marco_group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES marco_groups(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(device_id)
);

CREATE INDEX IF NOT EXISTS idx_mgm_group ON marco_group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_mgm_device ON marco_group_members(device_id);

-- Human readable policy change / sync logs ("YouTube blocked for Marco Phone").
CREATE TABLE IF NOT EXISTS marco_policy_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    group_id UUID REFERENCES marco_groups(id) ON DELETE SET NULL,
    device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'applied',
    router_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mpl_org ON marco_policy_logs(organization_id, created_at DESC);

-- Tracks consumed daily/monthly quota bytes for quota enforcement.
CREATE TABLE IF NOT EXISTS marco_quota_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES marco_groups(id) ON DELETE CASCADE,
    period_type VARCHAR(10) NOT NULL,
    period_key VARCHAR(20) NOT NULL,
    bytes_used BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(device_id, period_type, period_key)
);

CREATE INDEX IF NOT EXISTS idx_mqu_org ON marco_quota_usage(organization_id);
