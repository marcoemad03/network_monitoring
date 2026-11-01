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
	RouterPolicyWrites      bool
	RouterEnableLayer7      bool
	RouterEnableDNSBlock    bool
	RouterProtectedIPs      []string
	RouterMaxManagedEntries int
	// RouterPruneStale lets the Marco sync remove managed entries it no longer
	// wants (old groups, duplicates). Off by default: the sync only adds/updates.
	RouterPruneStale bool
	// RouterLegacyPolicyWrites lets the legacy policy engine write to the router
	// when RouterPolicyWrites is on. Off by default so it stays a dry-run.
	RouterLegacyPolicyWrites bool
	// RouterPlatformDstLists maps a platform key to an existing router address-list
	// whose addresses are blocked instead of the built-in IP ranges.
	RouterPlatformDstLists map[string]string
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
	cfg.RouterMaxManagedEntries = getEnvInt("ROUTER_MAX_MANAGED_ENTRIES", 400)
	cfg.RouterProtectedIPs = splitCSV(getEnv("ROUTER_PROTECTED_IPS", ""))
	cfg.RouterPruneStale = getEnvBool("ROUTER_PRUNE_STALE", false)
	cfg.RouterLegacyPolicyWrites = getEnvBool("ROUTER_LEGACY_POLICY_WRITES", false)
	cfg.RouterPlatformDstLists = parseKeyValueList(getEnv("ROUTER_PLATFORM_DST_LISTS", ""))

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
