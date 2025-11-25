import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs; 

  SettingsProvider(this._prefs) {
    _loadInstantSettings();
    _loadAsyncSettings();
  }

  //State variables (private)
  ThemeMode _themeMode = ThemeMode.light;
  bool _pushNotificationsEnabled = false;
  bool _isPhoneVerified = false;
  Set<String> _interests = {};
  RangeValues _ageRange = RangeValues(0, 0);


  //Getters
  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _pushNotificationsEnabled;
  bool get isPhoneVerified => _isPhoneVerified;
  Set<String> get interests => _interests;
  RangeValues get ageRange {
    int min = _prefs.getInt('min_age') ?? 18;
    int max = _prefs.getInt('max_age') ?? 60;
    return RangeValues(min.toDouble(), max.toDouble());
  }

  void _loadInstantSettings() {
    //theme  
    _themeMode = _prefs.getBool('isDark') ?? false ? ThemeMode.dark : ThemeMode.light;
    //is phone verified
    _isPhoneVerified = _prefs.getBool('isPhoneVerified') ?? false;
    //interests
    List<String>? savedList = _prefs.getStringList('user_interests');
    if(savedList != null) {
      _interests = savedList.toSet();
    }
    //age range
    int min = _prefs.getInt('min_age') ?? 18;
    int max = _prefs.getInt('max_age') ?? 60;
    _ageRange = RangeValues(min.toDouble(), max.toDouble());
  }

  Future<void> _loadAsyncSettings() async {
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
      //for test purposes only
      print("firebase delay");
      print(e);
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
        final preferences = await SharedPreferences.getInstance();
        await preferences.setBool('notifications_enabled', value);
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

  //add or remove interests
  void addRemoveInterests(String interest) {
    if(_interests.contains(interest)) {
      _interests.remove(interest);
    }
    else {
      _interests.add(interest);
    }
    notifyListeners();
    _saveInterests();
  }

  //store interests into disk
  void _saveInterests() {
    _prefs.setStringList('user_interests', _interests.toList());
  }

  //split range values to save them to disk
  void saveAgeRange(RangeValues values) {
    _prefs.setInt('min_age', values.start.round());
    _prefs.setInt('max_age', values.end.round());
    notifyListeners();
  }

  //
}
