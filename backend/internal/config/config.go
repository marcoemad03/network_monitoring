package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	ServerPort  int
	ServerHost  string
	Environment string

	DBHost        string
	DBPort        int
	DBUser        string
	DBPassword    string
	DBName        string
	DBSSLMode     string
	DBMaxConns    int
	DBMaxIdle     int
	DBMaxLifetime time.Duration

	RedisHost     string
	RedisPort     int
	RedisPassword string
	RedisDB       int

	JWTAccessSecret  string
	JWTRefreshSecret string
	JWTAccessExpiry  time.Duration
	JWTRefreshExpiry time.Duration
	JWTIssuer        string

	EncryptionKey string

	SMTPHost     string
	SMTPPort     int
	SMTPUser     string
	SMTPPassword string
	SMTPFrom     string

	RateLimitRequests     int
	RateLimitWindow       time.Duration
	RateLimitAuthRequests int
	RateLimitAuthWindow   time.Duration

	EnableMetrics bool
	MetricsPort   int
	SentryDSN     string

	LogLevel  string
	LogFormat string

	CORSAllowedOrigins string
	CORSAllowedMethods string

	ScanTimeout           time.Duration
	ScanConcurrency       int
	ScanDefaultPorts      string
	MikroTikAPITimeout    time.Duration
	MikroTikAPIRetryCount int
	PingTimeout           time.Duration
	TracerouteMaxHops     int

	// Router safety switches. Policy engines never modify the production router
	// unless RouterPolicyWrites is explicitly enabled; otherwise they only compute
	// and log the plan (dry-run).
	RouterPolicyWrites bool
	// AccessKey lets other PCs use this server; without it only this PC can.
	AccessKey string

	// LogCleanupFiles lists log files (patterns allowed) that lose entries older
	// than LogKeepDays.
	LogCleanupFiles []string
	LogKeepDays     int

	RouterEnableLayer7      bool
	RouterEnableDNSBlock    bool
	RouterProtectedIPs      []string
	RouterMaxManagedEntries int
	// RouterPruneStale lets the Marco sync remove managed entries it no longer
	// wants (removed devices, unblocked sites, old groups, duplicates). On by default,
	// so taking a device out of a blocked group lifts the block; see RouterMaxPrune.
	RouterPruneStale bool
	// RouterMaxPrune is the most router entries one sync may remove; a plan that
	// removes more is refused (ROUTER_MAX_PRUNE).
	RouterMaxPrune int
	// RouterLegacyPolicyWrites lets the legacy policy engine write to the router
	// when RouterPolicyWrites is on. Off by default so it stays a dry-run.
	RouterLegacyPolicyWrites bool
	// RouterPlatformDstLists maps a platform key to an existing router address-list
	// whose addresses are blocked instead of the built-in IP ranges.
	RouterPlatformDstLists map[string]string
	// RouterWANInterface overrides the internet interface otherwise detected from
	// the default route. RouterTelemetryInterval is how often the router is read
	// for speed and usage (0 disables it).
	RouterWANInterface      string
	RouterTelemetryInterval time.Duration
	// RouterClientPollInterval is how often the router is read for the device
	// inventory and per-device usage (0 disables it).
	RouterClientPollInterval time.Duration
	// Security scans read the router's whole connection table, which on a busy router
	// means thousands of rows and seconds of full CPU. They run only when someone
	// asks (interval 0) unless RouterSecurityScanInterval is set, never while the
	// router is above RouterScanMaxCPU, and never twice within RouterScanCooldown.
	RouterSecurityScanInterval time.Duration
	RouterScanMaxCPU           int
	RouterScanCooldown         time.Duration
	SecurityRetentionDays      int
	// RouterScanPlatformLists maps a platform name to a router address-list that
	// the hospital maintains for it (for example the tls-host "collect" lists).
	RouterScanPlatformLists map[string]string
	// Websites by name come from DNS lookups the hospital's own resolver sees. Two
	// sources, either or both: a UDP syslog listener (the resolver or router forwards
	// its query log here) and a Pi-hole whose query log is read over its API.
	// Nothing is listened on or polled unless it is configured.
	DNSSyslogListen    string // for example ":5514"; empty = off
	DNSSyslogAllow     []string
	PiholeURL          string
	PiholePassword     string // Pi-hole v6
	PiholeToken        string // Pi-hole v5 API token
	PiholeInsecureTLS  bool
	PiholePollInterval time.Duration
	DNSRetentionDays   int
	// MonitorSimulateMetrics makes the monitor store random device metrics (demo
	// data). Off by default: the dashboard must only show measured values.
	MonitorSimulateMetrics bool
}

func Load(cliPort int) (*Config, error) {
	_ = godotenv.Load()

	var serverPort int
	if cliPort > 0 {
		serverPort = cliPort
	} else {
		serverPort = getEnvInt("SERVER_PORT", 8080)
	}

	cfg := &Config{
		ServerPort:  serverPort,
		ServerHost:  getEnv("SERVER_HOST", "0.0.0.0"),
		Environment: getEnv("ENVIRONMENT", "development"),

		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnvInt("DB_PORT", 5432),
		DBUser:     getEnv("DB_USER", "nms_admin"),
		DBPassword: getEnv("DB_PASSWORD", ""),
		DBName:     getEnv("DB_NAME", "hospital_nms"),
		DBSSLMode:  getEnv("DB_SSLMODE", "disable"),
		DBMaxConns: getEnvInt("DB_MAX_CONNECTIONS", 50),
		DBMaxIdle:  getEnvInt("DB_MAX_IDLE_CONNECTIONS", 10),

		RedisHost:     getEnv("REDIS_HOST", "localhost"),
		RedisPort:     getEnvInt("REDIS_PORT", 6379),
		RedisPassword: getEnv("REDIS_PASSWORD", ""),
		RedisDB:       getEnvInt("REDIS_DB", 0),

		JWTAccessSecret:  getEnv("JWT_ACCESS_SECRET", "change-me"),
		JWTRefreshSecret: getEnv("JWT_REFRESH_SECRET", "change-me"),
		JWTIssuer:        getEnv("JWT_ISSUER", "hospital-nms"),

		EncryptionKey: getEnv("ENCRYPTION_KEY", ""),

		SMTPHost:     getEnv("SMTP_HOST", ""),
		SMTPPort:     getEnvInt("SMTP_PORT", 587),
		SMTPUser:     getEnv("SMTP_USER", ""),
		SMTPPassword: getEnv("SMTP_PASSWORD", ""),
		SMTPFrom:     getEnv("SMTP_FROM", ""),

		EnableMetrics: getEnvBool("ENABLE_METRICS", false),
		MetricsPort:   getEnvInt("METRICS_PORT", 9090),
		SentryDSN:     getEnv("SENTRY_DSN", ""),

		LogLevel:  getEnv("LOG_LEVEL", "info"),
		LogFormat: getEnv("LOG_FORMAT", "json"),

		CORSAllowedOrigins: getEnv("CORS_ALLOWED_ORIGINS", "*"),
		CORSAllowedMethods: getEnv("CORS_ALLOWED_METHODS", "GET,POST,PUT,PATCH,DELETE,OPTIONS"),

		ScanDefaultPorts: getEnv("SCAN_DEFAULT_PORTS", "22,80,443,8080,3389,8443"),
	}

	accessExpiry, err := time.ParseDuration(getEnv("JWT_ACCESS_EXPIRY", "15m"))
	if err != nil {
		return nil, fmt.Errorf("invalid JWT_ACCESS_EXPIRY: %w", err)
	}
	cfg.JWTAccessExpiry = accessExpiry

	refreshExpiry, err := time.ParseDuration(getEnv("JWT_REFRESH_EXPIRY", "720h"))
	if err != nil {
		return nil, fmt.Errorf("invalid JWT_REFRESH_EXPIRY: %w", err)
	}
	cfg.JWTRefreshExpiry = refreshExpiry

	dbMaxLife, err := time.ParseDuration(getEnv("DB_CONNECTION_MAX_LIFETIME", "30m"))
	if err != nil {
		return nil, fmt.Errorf("invalid DB_CONNECTION_MAX_LIFETIME: %w", err)
	}
	cfg.DBMaxLifetime = dbMaxLife

	scanTimeout, err := time.ParseDuration(getEnv("SCAN_TIMEOUT", "30s"))
	if err != nil {
		return nil, fmt.Errorf("invalid SCAN_TIMEOUT: %w", err)
	}
	cfg.ScanTimeout = scanTimeout

	pingTimeout, err := time.ParseDuration(getEnv("PING_TIMEOUT", "2s"))
	if err != nil {
		return nil, fmt.Errorf("invalid PING_TIMEOUT: %w", err)
	}
	cfg.PingTimeout = pingTimeout

	mikrotikTimeout, err := time.ParseDuration(getEnv("MIKROTIK_API_TIMEOUT", "10s"))
	if err != nil {
		return nil, fmt.Errorf("invalid MIKROTIK_API_TIMEOUT: %w", err)
	}
	cfg.MikroTikAPITimeout = mikrotikTimeout
	cfg.MikroTikAPIRetryCount = getEnvInt("MIKROTIK_API_RETRY_COUNT", 2)

	rateLimitWindow, err := time.ParseDuration(getEnv("RATE_LIMIT_WINDOW", "1m"))
	if err != nil {
		return nil, fmt.Errorf("invalid RATE_LIMIT_WINDOW: %w", err)
	}
	cfg.RateLimitWindow = rateLimitWindow

	rateLimitAuthWindow, err := time.ParseDuration(getEnv("RATE_LIMIT_AUTH_WINDOW", "1m"))
	if err != nil {
		return nil, fmt.Errorf("invalid RATE_LIMIT_AUTH_WINDOW: %w", err)
	}
	cfg.RateLimitAuthWindow = rateLimitAuthWindow

	cfg.RateLimitRequests = getEnvInt("RATE_LIMIT_REQUESTS", 100)
	cfg.RateLimitAuthRequests = getEnvInt("RATE_LIMIT_AUTH_REQUESTS", 10)
	cfg.ScanConcurrency = getEnvInt("SCAN_CONCURRENCY", 50)
	cfg.TracerouteMaxHops = getEnvInt("TRACEROUTE_MAX_HOPS", 30)

	cfg.RouterPolicyWrites = getEnvBool("ROUTER_POLICY_WRITES", false)
	cfg.RouterEnableLayer7 = getEnvBool("ROUTER_ENABLE_LAYER7", false)
	cfg.RouterEnableDNSBlock = getEnvBool("ROUTER_ENABLE_DNS_BLOCK", false)
	cfg.RouterMaxManagedEntries = getEnvInt("ROUTER_MAX_MANAGED_ENTRIES", 1000)
	cfg.AccessKey = getEnv("NMS_ACCESS_KEY", "")
	cfg.LogKeepDays = getEnvInt("LOG_KEEP_DAYS", 10)
	cfg.LogCleanupFiles = splitCSV(getEnv("LOG_CLEANUP_FILES", ""))
	cfg.RouterProtectedIPs = splitCSV(getEnv("ROUTER_PROTECTED_IPS", ""))
	cfg.RouterPruneStale = getEnvBool("ROUTER_PRUNE_STALE", true)
	cfg.RouterMaxPrune = getEnvInt("ROUTER_MAX_PRUNE", 60)
	cfg.RouterLegacyPolicyWrites = getEnvBool("ROUTER_LEGACY_POLICY_WRITES", false)
	cfg.RouterPlatformDstLists = parseKeyValueList(getEnv("ROUTER_PLATFORM_DST_LISTS", ""))
	cfg.RouterWANInterface = strings.TrimSpace(getEnv("ROUTER_WAN_INTERFACE", ""))
	telemetryInterval, err := time.ParseDuration(getEnv("ROUTER_TELEMETRY_INTERVAL", "15s"))
	if err != nil {
		return nil, fmt.Errorf("invalid ROUTER_TELEMETRY_INTERVAL: %w", err)
	}
	cfg.RouterTelemetryInterval = telemetryInterval
	clientInterval, err := time.ParseDuration(getEnv("ROUTER_CLIENT_POLL_INTERVAL", "30s"))
	if err != nil {
		return nil, fmt.Errorf("invalid ROUTER_CLIENT_POLL_INTERVAL: %w", err)
	}
	cfg.RouterClientPollInterval = clientInterval
	scanInterval, err := time.ParseDuration(getEnv("ROUTER_SECURITY_SCAN_INTERVAL", "0"))
	if err != nil {
		return nil, fmt.Errorf("invalid ROUTER_SECURITY_SCAN_INTERVAL: %w", err)
	}
	cfg.RouterSecurityScanInterval = scanInterval
	cfg.RouterScanMaxCPU = getEnvInt("ROUTER_SCAN_MAX_CPU", 85)
	scanCooldown, err := time.ParseDuration(getEnv("ROUTER_SCAN_COOLDOWN", "5m"))
	if err != nil {
		return nil, fmt.Errorf("invalid ROUTER_SCAN_COOLDOWN: %w", err)
	}
	cfg.RouterScanCooldown = scanCooldown
	cfg.SecurityRetentionDays = getEnvInt("SECURITY_RETENTION_DAYS", 30)
	cfg.RouterScanPlatformLists = parseKeyValueList(getEnv("ROUTER_SCAN_PLATFORM_LISTS", ""))
	cfg.DNSSyslogListen = getEnv("DNS_SYSLOG_LISTEN", "")
	cfg.DNSSyslogAllow = splitCSV(getEnv("DNS_SYSLOG_ALLOW", ""))
	cfg.PiholeURL = strings.TrimRight(getEnv("PIHOLE_URL", ""), "/")
	cfg.PiholePassword = getEnv("PIHOLE_PASSWORD", "")
	cfg.PiholeToken = getEnv("PIHOLE_API_TOKEN", "")
	cfg.PiholeInsecureTLS = getEnvBool("PIHOLE_INSECURE_TLS", false)
	piholePoll, err := time.ParseDuration(getEnv("PIHOLE_POLL_INTERVAL", "30s"))
	if err != nil {
		return nil, fmt.Errorf("invalid PIHOLE_POLL_INTERVAL: %w", err)
	}
	cfg.PiholePollInterval = piholePoll
	cfg.DNSRetentionDays = getEnvInt("DNS_RETENTION_DAYS", 30)
	cfg.MonitorSimulateMetrics = getEnvBool("MONITOR_SIMULATE_METRICS", false)

	return cfg, nil
}

func splitCSV(value string) []string {
	var out []string
	for _, part := range strings.Split(value, ",") {
		if part = strings.TrimSpace(part); part != "" {
			out = append(out, part)
		}
	}
	return out
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if value, ok := os.LookupEnv(key); ok {
		if i, err := strconv.Atoi(value); err == nil {
			return i
		}
	}
	return fallback
}

func getEnvBool(key string, fallback bool) bool {
	if value, ok := os.LookupEnv(key); ok {
		if b, err := strconv.ParseBool(value); err == nil {
			return b
		}
	}
	return fallback
}

// parseKeyValueList parses "key=value;key=value". Values may contain spaces
// (RouterOS list names do), so ";" is the separator.
func parseKeyValueList(value string) map[string]string {
	out := map[string]string{}
	for _, part := range strings.Split(value, ";") {
		k, v, ok := strings.Cut(part, "=")
		k, v = strings.TrimSpace(k), strings.TrimSpace(v)
		if ok && k != "" && v != "" {
			out[strings.ToLower(k)] = v
		}
	}
	return out
}
