-- Websites by name: what the devices asked the hospital's DNS for.
--
-- Only the registrable domain (example.com, not a page address) is kept, counted
-- per device per hour. Rows older than DNS_RETENTION_DAYS are deleted.

CREATE TABLE IF NOT EXISTS dns_activity (
    organization_id UUID NOT NULL REFERENCES organizations(id),
    bucket TIMESTAMPTZ NOT NULL,
    client_ip VARCHAR(45) NOT NULL,
    client_mac VARCHAR(17) NOT NULL DEFAULT '',
    site VARCHAR(255) NOT NULL,
    queries INT NOT NULL DEFAULT 0,
    blocked INT NOT NULL DEFAULT 0,
    PRIMARY KEY (organization_id, bucket, client_ip, site)
);

CREATE INDEX IF NOT EXISTS idx_dns_activity_org_time ON dns_activity(organization_id, bucket DESC);
CREATE INDEX IF NOT EXISTS idx_dns_activity_mac ON dns_activity(organization_id, client_mac, bucket DESC);

-- Names, categories and logos the hospital has given to sites (insurance
-- companies, for example). A logo is only ever downloaded for a site listed here.
CREATE TABLE IF NOT EXISTS site_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    name VARCHAR(120) NOT NULL,
    category VARCHAR(40) NOT NULL DEFAULT 'other',
    domains TEXT[] NOT NULL,
    logo BYTEA,
    logo_type VARCHAR(40),
    logo_source VARCHAR(255),
    logo_updated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_site_catalog_org ON site_catalog(organization_id);
CREATE INDEX IF NOT EXISTS idx_site_catalog_domains ON site_catalog USING GIN (domains);
