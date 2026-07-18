class AppConstants {
  AppConstants._();

  static const String appName = 'Hospital NMS';
  static const String companyName = 'Hospital Network Operations';
  static const String supportEmail = 'support@hospital-nms.com';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'cached_user';
  static const String themeKey = 'theme_preference';
  static const String localeKey = 'locale_preference';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Polling Intervals
  static const int devicePollIntervalMs = 30000;
  static const int alertPollIntervalMs = 15000;
  static const int metricsPollIntervalMs = 10000;

  // Validation
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 128;
  static const int nameMaxLength = 100;
  static const int descriptionMaxLength = 500;

  // Network
  static const int pingTimeoutMs = 5000;
  static const int traceRouteMaxHops = 30;
  static const int scanPortRangeStart = 1;
  static const int scanPortRangeEnd = 65535;

  // Security
  static const int maxLoginAttempts = 5;
  static const int lockoutDurationMinutes = 15;
  static const int sessionTimeoutMinutes = 60;
  static const int maxConcurrentSessions = 3;
}
