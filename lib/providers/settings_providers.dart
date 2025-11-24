import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs; 

  SettingsProvider(this._prefs) {
    bool isDark = _prefs.getBool('isDark') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    _isPhoneVerified = _prefs.getBool('isPhoneVerified') ?? false;
    _loadNotifications();
  }

  //State variables (private)
  ThemeMode _themeMode = ThemeMode.light;
  bool _pushNotificationsEnabled = false;
  bool _isPhoneVerified = false;

  //Getters
  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _pushNotificationsEnabled;
  bool get isPhoneVerified => _isPhoneVerified;

  Future<void> _loadNotifications() async {
    bool pushNotifications = _prefs.getBool('notifications_enabled') ?? false;
    try{
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.getNotificationSettings();

      if(settings.authorizationStatus == AuthorizationStatus.authorized && pushNotifications) {
        _pushNotificationsEnabled = true;
      }
      else {
        _pushNotificationsEnabled = false;
      }
       notifyListeners();
    } catch (e) {
      print("Firebase Delay");
    }
  }

  //Theme change function
  void toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('isDark', isDark);
  }

  //Push notifications logic
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
        //for test purposes only
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

  //Phone number logic
  void verifyPhone() async {
    _isPhoneVerified = true;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('isPhoneVerified', true);
  }

  void resetPhone() async {
    _isPhoneVerified = false;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPhoneVerified', false);
  }
}
