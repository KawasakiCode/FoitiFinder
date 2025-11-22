import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  // Getter to see current mode
  ThemeMode get themeMode => _themeMode;

  // Function to toggle mode
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class PushNotificationsProvider extends ChangeNotifier {
  bool _pushNotificationsEnabled = false;
  bool get notificationsEnabled => _pushNotificationsEnabled;

  Future<void> toggleNotifications(bool value) async {
    //when user first turns the switch to on the app asks for permissions
    if (value == true) {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(  
        alert: true,
        badge: true,
        sound: true,
      );
      //if user accepts permissions they are enabled and switch stays on
      if(settings.authorizationStatus == AuthorizationStatus.authorized) {
        _pushNotificationsEnabled = true;
        String? token = await messaging.getToken();
        print(token);
      }
      //if user declines then switch stays off and no notifications can be sent
      else {
        _pushNotificationsEnabled = false;
      }
    }
    //if the switch is gets turned off stop sending notifications
    else {
      _pushNotificationsEnabled = false;
    }
    notifyListeners();
  }
}