-- Add missing columns to device_metrics table for monitoring data
ALTER TABLE device_metrics ADD COLUMN IF NOT EXISTS upload_speed_bps BIGINT;
ALTER TABLE device_metrics ADD COLUMN IF NOT EXISTS download_speed_bps BIGINT;
ALTER TABLE device_metrics ADD COLUMN IF NOT EXISTS signal_strength_dbm INT;
ALTER TABLE device_metrics ADD COLUMN IF NOT EXISTS signal_quality_percent DECIMAL(5,2);
ALTER TABLE device_metrics ADD COLUMN IF NOT EXISTS connected_ap_id UUID REFERENCES devices(id) ON DELETE SET NULL;
ALTER TABLE device_metrics ADD COLUMN IF NOT EXISTS connected_switch_id UUID REFERENCES devices(id) ON DELETE SET NULL;
