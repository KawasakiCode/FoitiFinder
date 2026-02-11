//settings model for the user's settings that will be sent to the database
//only settings that don't affect the matching algorithm are here (darkmode, notifications, language)

class SettingsModel{
  final int userId;
  final bool? isDark;
  final bool? isNotificationsOn;
  final String? language;

  SettingsModel({
    required this.userId,
    this.isDark,
    this.isNotificationsOn,
    this.language,    
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel ( 
      userId: json['user_id'] ?? (throw Exception("Critical: user_id missing")),
      isDark: json['is_dark_mode'],
      isNotificationsOn: json['is_notifications_on'],
      language: json['language'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'is_dark_mode': isDark,
      'is_notification_on': isNotificationsOn,
      'language': language,
    };
  }
}