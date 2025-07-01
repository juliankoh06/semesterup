class ReminderSettings {
  final bool enabled;
  final Duration timeBefore;

  ReminderSettings({required this.enabled, required this.timeBefore});

  static ReminderSettings defaultSettings() {
    return ReminderSettings(
      enabled: true,
      timeBefore: Duration(hours: 24),
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'timeBefore': timeBefore.inMinutes,
  };

  factory ReminderSettings.fromMap(Map<String, dynamic> map) => ReminderSettings(
    enabled: map['enabled'] ?? false,
    timeBefore: Duration(minutes: map['timeBefore'] ?? 0),
  );
}