# Database Architecture - Hospital NMS

## Technology
- **PostgreSQL 16+** with TimescaleDB extension for time-series metrics
- **pg_stat_statements** for query performance monitoring
- **pgcrypto** for encryption functions

## Database Schema

### 1. organizations
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, DEFAULT gen_random_uuid() |
| name | VARCHAR(200) | NOT NULL |
| code | VARCHAR(20) | UNIQUE, NOT NULL |
| settings | JSONB | DEFAULT '{}' |
| is_active | BOOLEAN | DEFAULT true |
| created_at | TIMESTAMPTZ | DEFAULT NOW() |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() |

### 2. users
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| organization_id | UUID | FK -> organizations.id |
| username | VARCHAR(100) | UNIQUE, NOT NULL |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL |
| display_name | VARCHAR(200) | |
| first_name | VARCHAR(100) | |
| last_name | VARCHAR(100) | |
| role | ENUM | 'admin','operator','viewer','auditor' |
| department | VARCHAR(100) | |
| title | VARCHAR(100) | |
| phone | VARCHAR(50) | |
| is_active | BOOLEAN | DEFAULT true |
| is_locked | BOOLEAN | DEFAULT false |
| is_mfa_enabled | BOOLEAN | DEFAULT false |
| mfa_secret | VARCHAR(100) | |
| failed_login_attempts | INT | DEFAULT 0 |
| locked_until | TIMESTAMPTZ | |
| last_login_at | TIMESTAMPTZ | |
| last_login_ip | INET | |
| password_changed_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | DEFAULT NOW() |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() |

### 3. devices
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| organization_id | UUID | FK -> organizations.id |
| name | VARCHAR(200) | NOT NULL |
| hostname | VARCHAR(255) | |
| ip_address | INET | NOT NULL |
| mac_address | MACADDR | |
| device_type | ENUM | See DeviceType enum |
| status | ENUM | 'online','offline','degraded','maintenance','unknown','unmanaged' |
| vendor | VARCHAR(100) | |
| model | VARCHAR(100) | |
| serial_number | VARCHAR(100) | |
| os_version | VARCHAR(100) | |
| firmware_version | VARCHAR(100) | |
| location | VARCHAR(200) | |
| department | VARCHAR(100) | |
| notes | TEXT | |
| custom_fields | JSONB | DEFAULT '{}' |
| first_seen | TIMESTAMPTZ | DEFAULT NOW() |
| last_boot | TIMESTAMPTZ | |
| last_seen | TIMESTAMPTZ | DEFAULT NOW() |
| is_critical | BOOLEAN | DEFAULT false |
| is_monitored | BOOLEAN | DEFAULT true |
| snmp_community | VARCHAR(100) | ENCRYPTED |
| snmp_version | VARCHAR(5) | 'v1','v2c','v3' |
| snmp_port | INT | DEFAULT 161 |
| created_at | TIMESTAMPTZ | DEFAULT NOW() |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() |

### 4. interfaces
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| device_id | UUID | FK -> devices.id ON DELETE CASCADE |
| name | VARCHAR(100) | NOT NULL |
| description | VARCHAR(255) | |
| mac_address | MACADDR | |
| ip_address | INET | |
| subnet_mask | INET | |
| gateway | INET | |
| dns_servers | INET[] | |
| connection_type | ENUM | 'ethernet','wifi','fiber','cellular','satellite','vpn','virtual' |
| is_up | BOOLEAN | DEFAULT false |
| is_management | BOOLEAN | DEFAULT false |
| mtu | INT | DEFAULT 1500 |
| speed_mbps | DECIMAL(10,2) | |
| duplex | VARCHAR(10) | 'full','half','auto' |
| media_type | VARCHAR(50) | |
| index | INT | DEFAULT 0 |
| vlan_id | INT | 1-4094 |
| switch_port | VARCHAR(50) | |
| connected_device_id | UUID | FK -> devices.id |
| connected_interface_name | VARCHAR(100) | |
| bytes_in | BIGINT | DEFAULT 0 |
| bytes_out | BIGINT | DEFAULT 0 |
| packets_in | BIGINT | DEFAULT 0 |
| packets_out | BIGINT | DEFAULT 0 |
| errors_in | BIGINT | DEFAULT 0 |
| errors_out | BIGINT | DEFAULT 0 |
| drops_in | BIGINT | DEFAULT 0 |
| drops_out | BIGINT | DEFAULT 0 |
| utilization_percent | DECIMAL(5,2) | |
| last_status_change | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | DEFAULT NOW() |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() |

### 5. device_metrics (TimescaleDB hypertable)
| Column | Type | Constraints |
|--------|------|-------------|
| device_id | UUID | FK -> devices.id |
| cpu_usage_percent | DECIMAL(5,2) | |
| memory_usage_percent | DECIMAL(5,2) | |
| disk_usage_percent | DECIMAL(5,2) | |
| temperature_celsius | DECIMAL(5,2) | |
| uptime_seconds | BIGINT | |
| total_traffic_in_bps | BIGINT | |
| total_traffic_out_bps | BIGINT | |
| average_latency_ms | DECIMAL(10,2) | |
| max_latency_ms | DECIMAL(10,2) | |
| packet_loss_percent | DECIMAL(5,2) | |
| total_alerts | INT | |
| critical_alerts | INT | |
| timestamp | TIMESTAMPTZ | NOT NULL |

### 6. alerts
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| organization_id | UUID | FK -> organizations.id |
| title | VARCHAR(255) | NOT NULL |
| description | TEXT | |
| severity | ENUM | 'critical','high','medium','low','info' |
| status | ENUM | 'open','acknowledged','resolved','suppressed' |
| category | ENUM | 'connectivity','performance','security','hardware','configuration','capacity','environmental' |
| device_id | UUID | FK -> devices.id |
| interface_id | UUID | FK -> interfaces.id |
| metric_name | VARCHAR(100) | |
| metric_value | DECIMAL(15,2) | |
| threshold_value | DECIMAL(15,2) | |
| rule_id | UUID | |
| acknowledged_by | UUID | FK -> users.id |
| acknowledged_at | TIMESTAMPTZ | |
| resolved_by | UUID | FK -> users.id |
| resolved_at | TIMESTAMPTZ | |
| resolution_notes | TEXT | |
| occurrence_count | INT | DEFAULT 1 |
| is_suppressed | BOOLEAN | DEFAULT false |
| suppressed_until | TIMESTAMPTZ | |
| detected_at | TIMESTAMPTZ | DEFAULT NOW() |
| created_at | TIMESTAMPTZ | DEFAULT NOW() |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() |

### 7. network_scans
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| organization_id | UUID | FK -> organizations.id |
| type | ENUM | 'arp','ping','port','snmp','topology','nmap' |
| status | ENUM | 'pending','running','completed','failed','cancelled' |
| name | VARCHAR(200) | |
| target_subnet | CIDR | NOT NULL |
| target_ips | INET[] | |
| port_range | VARCHAR(50) | |
| ports | INT[] | |
| initiated_by | UUID | FK -> users.id |
| total_hosts | INT | DEFAULT 0 |
| discovered_hosts | INT | DEFAULT 0 |
| active_hosts | INT | DEFAULT 0 |
| duration_seconds | INT | |
| progress | DECIMAL(5,2) | |
| error_message | TEXT | |
| result_summary | TEXT | |
| started_at | TIMESTAMPTZ | DEFAULT NOW() |
| completed_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | DEFAULT NOW() |

### 8. scan_results
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| scan_id | UUID | FK -> network_scans.id ON DELETE CASCADE |
| ip_address | INET | NOT NULL |
| hostname | VARCHAR(255) | |
| mac_address | MACADDR | |
| vendor | VARCHAR(100) | |
| open_ports | INT[] | |
| os_guess | VARCHAR(100) | |
| response_time_ms | DECIMAL(10,2) | |
| is_alive | BOOLEAN | DEFAULT false |
| is_new_device | BOOLEAN | DEFAULT false |
| discovered_at | TIMESTAMPTZ | DEFAULT NOW() |

### 9. audit_logs
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| organization_id | UUID | FK -> organizations.id |
| action | ENUM | 'login','logout','create','update','delete','acknowledge','resolve','scan','export','configuration','permission_change' |
| entity_type | ENUM | 'device','interface','alert','user','scan','configuration','system' |
| entity_id | UUID | |
| entity_name | VARCHAR(200) | |
| performed_by | UUID | FK -> users.id |
| ip_address | INET | |
| user_agent | TEXT | |
| previous_values | JSONB | |
| new_values | JSONB | |
| description | TEXT | |
| is_success | BOOLEAN | DEFAULT true |
| failure_reason | TEXT | |
| timestamp | TIMESTAMPTZ | DEFAULT NOW() |

### 10. refresh_tokens
| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK |
| user_id | UUID | FK -> users.id ON DELETE CASCADE |
| token_hash | VARCHAR(255) | NOT NULL |
| expires_at | TIMESTAMPTZ | NOT NULL |
| is_revoked | BOOLEAN | DEFAULT false |
| created_at | TIMESTAMPTZ | DEFAULT NOW() |
| ip_address | INET | |
| user_agent | TEXT | |

## Indexes
- devices: idx_devices_org_status (organization_id, status)
- devices: idx_devices_ip (ip_address)
- devices: idx_devices_mac (mac_address)
- devices: idx_devices_type (device_type)
- interfaces: idx_interfaces_device (device_id)
- interfaces: idx_interfaces_ip (ip_address)
- alerts: idx_alerts_status (status)
- alerts: idx_alerts_severity (severity)
- alerts: idx_alerts_device (device_id)
- alerts: idx_alerts_detected (detected_at DESC)
- audit_logs: idx_audit_timestamp (timestamp DESC)
- audit_logs: idx_audit_entity (entity_type, entity_id)
- audit_logs: idx_audit_performer (performed_by)
- refresh_tokens: idx_refresh_token_hash (token_hash)
- refresh_tokens: idx_refresh_user (user_id)

## Partitions
- audit_logs: PARTITION BY RANGE (timestamp) - Monthly
- device_metrics: TimescaleDB hypertable by timestamp (1 hour chunks)
- alerts: PARTITION BY RANGE (created_at) - Monthly
