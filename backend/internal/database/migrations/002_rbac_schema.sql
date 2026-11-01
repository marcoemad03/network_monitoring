-- Hospital NMS - RBAC & Session Management Schema

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    permission_level INT NOT NULL DEFAULT 0,
    is_system_role BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    module VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    refresh_token_hash VARCHAR(255) NOT NULL,
    ip_address INET,
    user_agent TEXT,
    last_activity TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    is_revoked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS password_reset_token VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_reset_expires_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_history JSONB DEFAULT '[]';

CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON user_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(user_id, is_revoked, expires_at);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_perm ON role_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_permissions_module ON permissions(module);

-- Seed default roles
INSERT INTO roles (id, name, slug, description, permission_level, is_system_role) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'Super Admin', 'super_admin', 'Full system access with all permissions', 100, true),
    ('a0000000-0000-0000-0000-000000000002', 'Network Administrator', 'network_admin', 'Manage devices, alerts, scans, and network configuration', 80, true),
    ('a0000000-0000-0000-0000-000000000003', 'IT Support', 'it_support', 'View devices, acknowledge alerts, perform basic troubleshooting', 60, true),
    ('a0000000-0000-0000-0000-000000000004', 'Read Only', 'read_only', 'View dashboards and reports, no modifications', 30, true)
ON CONFLICT (slug) DO NOTHING;

-- Seed permissions
INSERT INTO permissions (id, name, slug, description, module) VALUES
    -- User Management
    ('b0000000-0000-0000-0000-000000000001', 'List Users', 'users.list', 'View list of all users', 'users'),
    ('b0000000-0000-0000-0000-000000000002', 'Create Users', 'users.create', 'Create new user accounts', 'users'),
    ('b0000000-0000-0000-0000-000000000003', 'Edit Users', 'users.edit', 'Modify user account details', 'users'),
    ('b0000000-0000-0000-0000-000000000004', 'Delete Users', 'users.delete', 'Remove user accounts', 'users'),
    ('b0000000-0000-0000-0000-000000000005', 'Manage Roles', 'users.manage_roles', 'Assign and modify user roles', 'users'),
    -- Device Management
    ('c0000000-0000-0000-0000-000000000001', 'List Devices', 'devices.list', 'View device inventory', 'devices'),
    ('c0000000-0000-0000-0000-000000000002', 'Create Devices', 'devices.create', 'Add new devices', 'devices'),
    ('c0000000-0000-0000-0000-000000000003', 'Edit Devices', 'devices.edit', 'Modify device configuration', 'devices'),
    ('c0000000-0000-0000-0000-000000000004', 'Delete Devices', 'devices.delete', 'Remove devices from inventory', 'devices'),
    -- Alert Management
    ('d0000000-0000-0000-0000-000000000001', 'List Alerts', 'alerts.list', 'View alert list', 'alerts'),
    ('d0000000-0000-0000-0000-000000000002', 'Acknowledge Alerts', 'alerts.acknowledge', 'Acknowledge and take ownership of alerts', 'alerts'),
    ('d0000000-0000-0000-0000-000000000003', 'Resolve Alerts', 'alerts.resolve', 'Resolve and close alerts', 'alerts'),
    -- Network Scan
    ('e0000000-0000-0000-0000-000000000001', 'Start Scans', 'scans.start', 'Initiate network discovery scans', 'scans'),
    ('e0000000-0000-0000-0000-000000000002', 'View Scan Results', 'scans.view', 'View scan results and history', 'scans'),
    -- Audit
    ('f0000000-0000-0000-0000-000000000001', 'View Audit Logs', 'audit.view', 'View audit trail', 'audit'),
    ('f0000000-0000-0000-0000-000000000002', 'Export Audit Logs', 'audit.export', 'Export audit log data', 'audit'),
    -- System
    ('90000000-0000-0000-0000-000000000001', 'System Configuration', 'system.configure', 'Modify system settings', 'system'),
    ('90000000-0000-0000-0000-000000000002', 'View Dashboard', 'system.dashboard', 'View main dashboard', 'system'),
    -- Permissions
    ('91000000-0000-0000-0000-000000000001', 'Manage Permissions', 'permissions.manage', 'Manage role-permission assignments', 'permissions')
ON CONFLICT (slug) DO NOTHING;

-- Assign permissions to Super Admin (all permissions)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'a0000000-0000-0000-0000-000000000001', id FROM permissions
ON CONFLICT DO NOTHING;

-- Assign permissions to Network Administrator
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'a0000000-0000-0000-0000-000000000002', id FROM permissions
WHERE slug IN (
    'devices.list', 'devices.create', 'devices.edit', 'devices.delete',
    'alerts.list', 'alerts.acknowledge', 'alerts.resolve',
    'scans.start', 'scans.view',
    'audit.view',
    'system.dashboard',
    'users.list'
)
ON CONFLICT DO NOTHING;

-- Assign permissions to IT Support
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'a0000000-0000-0000-0000-000000000003', id FROM permissions
WHERE slug IN (
    'devices.list',
    'alerts.list', 'alerts.acknowledge',
    'scans.view',
    'system.dashboard'
)
ON CONFLICT DO NOTHING;

-- Assign permissions to Read Only
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'a0000000-0000-0000-0000-000000000004', id FROM permissions
WHERE slug IN (
    'devices.list',
    'alerts.list',
    'system.dashboard'
)
ON CONFLICT DO NOTHING;

CREATE TRIGGER update_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_role_permissions_updated_at
    BEFORE UPDATE ON role_permissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
