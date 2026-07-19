CREATE TABLE device_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    parent_group_id UUID REFERENCES device_groups(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_device_groups_org ON device_groups(organization_id);
CREATE INDEX idx_device_groups_parent ON device_groups(parent_group_id);

CREATE TABLE device_group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES device_groups(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(device_id, group_id)
);

CREATE INDEX idx_dgm_device ON device_group_members(device_id);
CREATE INDEX idx_dgm_group ON device_group_members(group_id);

CREATE TABLE floor_maps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    name VARCHAR(200) NOT NULL,
    image_path TEXT DEFAULT '',
    width INT NOT NULL DEFAULT 1000,
    height INT NOT NULL DEFAULT 800,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_floor_maps_org ON floor_maps(organization_id);

CREATE TABLE floor_map_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    floor_map_id UUID NOT NULL REFERENCES floor_maps(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    x_coord DOUBLE PRECISION NOT NULL DEFAULT 0,
    y_coord DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(floor_map_id, device_id)
);

CREATE INDEX idx_fmd_map ON floor_map_devices(floor_map_id);
CREATE INDEX idx_fmd_device ON floor_map_devices(device_id);

CREATE TABLE asset_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL UNIQUE REFERENCES devices(id) ON DELETE CASCADE,
    department VARCHAR(200),
    floor_name VARCHAR(200),
    room VARCHAR(200),
    switch_port VARCHAR(100),
    access_point_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_asset_details_device ON asset_details(device_id);
CREATE INDEX idx_asset_details_department ON asset_details(department);
CREATE INDEX idx_asset_details_floor ON asset_details(floor_name);

CREATE TABLE policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    policy_type VARCHAR(50) NOT NULL,
    config JSONB NOT NULL DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_policies_org ON policies(organization_id);
CREATE INDEX idx_policies_type ON policies(policy_type);

CREATE TABLE policy_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id UUID NOT NULL REFERENCES policies(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES device_groups(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(policy_id, group_id)
);

CREATE INDEX idx_pa_policy ON policy_assignments(policy_id);
CREATE INDEX idx_pa_group ON policy_assignments(group_id);

CREATE TABLE sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    vendor_integration_id UUID REFERENCES vendor_integrations(id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    details JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sync_logs_org ON sync_logs(organization_id);
CREATE INDEX idx_sync_logs_vendor ON sync_logs(vendor_integration_id);
