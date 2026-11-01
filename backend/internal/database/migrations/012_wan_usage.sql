-- Internet usage measured from the router's WAN interface counters.
-- One row per sample: the bytes moved since the previous sample plus the raw
-- interface counters, so usage can be resumed correctly after a server restart.

CREATE TABLE IF NOT EXISTS wan_usage_samples (
    id BIGSERIAL PRIMARY KEY,
    organization_id UUID NOT NULL REFERENCES organizations(id),
    interface_name VARCHAR(100) NOT NULL,
    sampled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    rx_counter BIGINT NOT NULL,
    tx_counter BIGINT NOT NULL,
    rx_bytes_delta BIGINT NOT NULL DEFAULT 0,
    tx_bytes_delta BIGINT NOT NULL DEFAULT 0,
    rx_bps BIGINT NOT NULL DEFAULT 0,
    tx_bps BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_wan_usage_org_time ON wan_usage_samples(organization_id, sampled_at DESC);
