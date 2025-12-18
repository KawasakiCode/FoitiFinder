//the provider that loads and changes global settings like dark mode, language. 
//used only for settings within the settings page

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:foitifinder/models/settings_model.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RecommendationPreference {balanced, recentlyActive}

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  SettingsProvider(this._prefs);

  //function that automatically runs when provider is initialized
  //loads user from disk, if disk empty then loads user from database
  Future<void> init() async {
    _loadFromDisk();

    final user = FirebaseAuth.instance.currentUser;
    if(user != null) {
      fetchSettingsFromApi();
      loadAsyncSettings();
    }
  }

  //State variables (private)
  ThemeMode _themeMode = ThemeMode.light;
  bool _pushNotificationsEnabled = false;
  bool _isPhoneVerified = false;
  Set<String> _interests = {};
  RangeValues _ageRange = RangeValues(0, 0);
  bool _showOutOfRange = false;
  RecommendationPreference _currentOpt = RecommendationPreference.balanced;
  Locale _locale = const Locale('el');

  //Getters
  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _pushNotificationsEnabled;
  bool get isPhoneVerified => _isPhoneVerified;
  Set<String> get interests => _interests;
  RangeValues get ageRange => _ageRange;
  bool get showOutOfRange => _showOutOfRange;
  RecommendationPreference get currentOpt => _currentOpt;
  Locale get locale => _locale;

  void _loadFromDisk() {
    _themeMode = ThemeMode.light;
    _pushNotificationsEnabled = false;
    _locale = Locale('el');
  }

  Future<void> fetchSettingsFromApi() async {
    //theme  
    if(_prefs.getBool('isDark') == null) {
      SettingsModel data = await ApiService.getUsersSettings(FirebaseAuth.instance.currentUser!.uid);
      _themeMode = data.isDark! ? ThemeMode.dark : ThemeMode.light;
      _prefs.setBool('isDark', data.isDark!);
    }

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

    //show out of age range
    _showOutOfRange = _prefs.getBool('outOfRange') ?? false;

    //recommendation preference
    String? savedValue = _prefs.getString('recommendationOpt');
    if(savedValue != null) {
      _currentOpt = RecommendationPreference.values.firstWhere(
        (e) => e.name == savedValue,
        orElse: () => RecommendationPreference.balanced
      );
    }

    String langCode;
    if(_prefs.getString('language_code') == null) {
      SettingsModel data = await ApiService.getUsersSettings(FirebaseAuth.instance.currentUser!.uid);
      langCode =  data.language!;
      _locale = Locale(langCode);
      _prefs.setString('language_code', data.language!);
    }

    notifyListeners();
  }

  Future<void> loadAsyncSettings() async {
    bool diskVerified = _prefs.getBool('isPhoneVerified') ?? false;
    final user = FirebaseAuth.instance.currentUser;
    bool cloudVerified = user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty;
    if(cloudVerified) {
      _isPhoneVerified = true;
      if(!diskVerified) {
        await _prefs.setBool('isPhoneVerified', true);
      }
    }

    bool pushNotifications;
    if(_prefs.getBool('notifications_enabled') == null) {
      SettingsModel data = await ApiService.getUsersSettings(FirebaseAuth.instance.currentUser!.uid);
      _prefs.setBool('notifications_enabled', data.isNotificationsOn!);
      pushNotifications = data.isNotificationsOn!;
    }
    else {
      pushNotifications = _prefs.getBool('notifications_enabled') ?? false;
    }
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
      _pushNotificationsEnabled = false;
    }
  }

  //Theme change function
  void toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('isDark', isDark);
    await ApiService.updateUsersSettings(isDarkMode:  isDark, uid: FirebaseAuth.instance.currentUser!.uid);
    
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
        //token to identify specific user to send push notifications
        //String? token = await messaging.getToken();
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
    await ApiService.updateUsersSettings(uid: FirebaseAuth.instance.currentUser!.uid, isNotificationsOn: _pushNotificationsEnabled);
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
    _ageRange = values;
    _prefs.setInt('min_age', values.start.round());
    _prefs.setInt('max_age', values.end.round());
    notifyListeners();
  }

  //store out of range switch state
  void storeShowOutOfRange(bool outOfRange) {
    _showOutOfRange = outOfRange;
    _prefs.setBool('outOfRange', outOfRange);
    notifyListeners();
  }

  //recommendation preference
  void changeRecommendationPreference(RecommendationPreference opt) {
    _currentOpt = opt;
    notifyListeners();
    _prefs.setString('recommendationOpt', opt.name);
  }

  void changeLanguage(String languageCode) async {
    _locale = Locale(languageCode);
    notifyListeners();
    _prefs.setString('language_code', languageCode);
    await ApiService.updateUsersSettings(uid: FirebaseAuth.instance.currentUser!.uid, language: languageCode);
  }

  //for _prefs cleanup
  Future<void> clearData() async {
    await _prefs.remove('isPhoneVerified');
    await _prefs.remove('isDark');
    await _prefs.remove('user_interests');
    await _prefs.remove('min_age');
    await _prefs.remove('max_age');
    await _prefs.remove('outOfRange');
    await _prefs.remove('recommendationOpt');
    await _prefs.remove('language_code');
    await _prefs.remove('notifications_enabled');
    _themeMode = ThemeMode.light;
    _pushNotificationsEnabled = false;
    _locale = Locale('el');
    notifyListeners();
  }
}
