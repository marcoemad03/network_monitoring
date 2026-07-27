class TelegramConfig {
  final String botToken;
  final String chatId;
  final int gracePeriodMinutes;
  final bool oncePerDay;
  final bool notifyConnect;
  final bool notifyDisconnect;
  final bool notifyNewDevice;
  final bool notifyPolicyViolation;
  final bool enabled;

  const TelegramConfig({
    required this.botToken,
    required this.chatId,
    required this.gracePeriodMinutes,
    required this.oncePerDay,
    required this.notifyConnect,
    required this.notifyDisconnect,
    required this.notifyNewDevice,
    required this.notifyPolicyViolation,
    required this.enabled,
  });

  factory TelegramConfig.fromJson(Map<String, dynamic> json) {
    return TelegramConfig(
      botToken: json['bot_token'] as String? ?? '',
      chatId: json['chat_id'] as String? ?? '',
      gracePeriodMinutes: json['grace_period_minutes'] as int? ?? 5,
      oncePerDay: json['once_per_day'] as bool? ?? true,
      notifyConnect: json['notify_connect'] as bool? ?? true,
      notifyDisconnect: json['notify_disconnect'] as bool? ?? true,
      notifyNewDevice: json['notify_new_device'] as bool? ?? true,
      notifyPolicyViolation: json['notify_policy_violation'] as bool? ?? true,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'bot_token': botToken,
    'chat_id': chatId,
    'grace_period_minutes': gracePeriodMinutes,
    'once_per_day': oncePerDay,
    'notify_connect': notifyConnect,
    'notify_disconnect': notifyDisconnect,
    'notify_new_device': notifyNewDevice,
    'notify_policy_violation': notifyPolicyViolation,
    'enabled': enabled,
  };
}
