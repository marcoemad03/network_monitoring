class HotspotWelcomeConfig {
  final String hospitalName;
  final String logoUrl;
  final String primaryColor;
  final String accentColor;
  final String welcomeMessage;
  final List<String> announcements;
  final bool enabled;

  const HotspotWelcomeConfig({
    required this.hospitalName,
    required this.logoUrl,
    required this.primaryColor,
    required this.accentColor,
    required this.welcomeMessage,
    required this.announcements,
    required this.enabled,
  });

  factory HotspotWelcomeConfig.fromJson(Map<String, dynamic> json) {
    return HotspotWelcomeConfig(
      hospitalName: json['hospital_name'] as String? ?? '',
      logoUrl: json['logo_url'] as String? ?? '',
      primaryColor: json['primary_color'] as String? ?? '#0B6E69',
      accentColor: json['accent_color'] as String? ?? '#F2B134',
      welcomeMessage: json['welcome_message'] as String? ?? '',
      announcements: (json['announcements'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'hospital_name': hospitalName,
    'logo_url': logoUrl,
    'primary_color': primaryColor,
    'accent_color': accentColor,
    'welcome_message': welcomeMessage,
    'announcements': announcements,
    'enabled': enabled,
  };
}

class HotspotProfileResult {
  final bool profileConfigured;
  final bool fileUploaded;
  final String htmlDirectory;
  final String message;

  const HotspotProfileResult({
    required this.profileConfigured,
    required this.fileUploaded,
    required this.htmlDirectory,
    required this.message,
  });

  factory HotspotProfileResult.fromJson(Map<String, dynamic> json) {
    return HotspotProfileResult(
      profileConfigured: json['profile_configured'] as bool? ?? false,
      fileUploaded: json['file_uploaded'] as bool? ?? false,
      htmlDirectory: json['html_directory'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}
