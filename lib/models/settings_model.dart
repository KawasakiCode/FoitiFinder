//settings model for the user's settings that will be sent to the database
//only settings that don't affect the matching algorithm are here (darkmode, notifications, language)

class SettingsModel{
  final int userId;
  final bool? isDark;
  final bool? isMatchNotificationsOn;
  final String? language;

  SettingsModel({
    required this.userId,
    this.isDark,
    this.isMatchNotificationsOn,
    this.language,
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel (
      userId: json['user_id'] ?? (throw Exception("Critical: user_id missing")),
      isDark: json['is_dark_mode'],
      isMatchNotificationsOn: json['is_match_notifications_on'],
      language: json['language'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'is_dark_mode': isDark,
      //MATCHES fromJson ABOVE, which it did not: this said
      //is_like_notification_on - singular, and nothing has ever read
      //that key. Harmless only because toMap has no callers yet.
      'is_match_notifications_on': isMatchNotificationsOn,
      'language': language,
    };
  }
}