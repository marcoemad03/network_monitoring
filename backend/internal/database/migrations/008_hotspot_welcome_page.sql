CREATE TABLE hotspot_welcome_configs (
    organization_id UUID PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
    hospital_name VARCHAR(200) NOT NULL,
    logo_url TEXT NOT NULL DEFAULT '',
    primary_color VARCHAR(7) NOT NULL DEFAULT '#0B6E69' CHECK (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
    accent_color VARCHAR(7) NOT NULL DEFAULT '#F2B134' CHECK (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
    welcome_message TEXT NOT NULL DEFAULT '',
    announcements JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(announcements) = 'array'),
    enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
