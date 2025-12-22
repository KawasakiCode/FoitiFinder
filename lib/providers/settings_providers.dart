//the provider that loads and changes global settings like dark mode, language. 
//used only for settings within the settings page

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:foitifinder/models/settings_model.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

enum RecommendationPreference {balanced, recentlyActive}

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  //the provider when initialized loads data from disk or if disk is empty loads the defaults
  //using this way we save the time of making a call to the db
  //99% of the time disk will be correct anyway
  SettingsProvider(this._prefs){
    _themeMode = (_prefs.getBool('isDark') ?? false) ? ThemeMode.light : ThemeMode.dark;
    _pushNotificationsEnabled = (_prefs.getBool('notifications_enabled') ?? false) ? true : false;
    _locale = _prefs.getString('language') == 'en' ? Locale('en') : Locale('el');
    _ageRange = RangeValues(18, 30);
    _interests = {};
    _currentOpt = RecommendationPreference.balanced;
    _showOutOfRange = false;
    _isPhoneVerified = false;
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
  bool _osPermission = false;

  //Getters
  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _pushNotificationsEnabled;
  bool get isPhoneVerified => _isPhoneVerified;
  Set<String> get interests => _interests;
  RangeValues get ageRange => _ageRange;
  bool get showOutOfRange => _showOutOfRange;
  RecommendationPreference get currentOpt => _currentOpt;
  Locale get locale => _locale;
  bool get osPermission => _osPermission;

  Future<void> fetchSettingsFromApi(String uid) async {
    SettingsModel data = await ApiService.getUsersSettings(uid);
    UserModel? userData = await ApiService.getUserData(uid);
    //theme  
    if(_prefs.getBool('isDark') == null) {
      bool isDark = data.isDark ?? false;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _prefs.setBool('isDark', isDark);
    }
    else {
      _themeMode = _prefs.getBool('isDark')! ? ThemeMode.dark : ThemeMode.light;
    }

    //is phone verified
    _isPhoneVerified = _prefs.getBool('isPhoneVerified') ?? false;

    //interests
    if(_prefs.getStringList('user_interests') == null) {
      _interests =  (userData?.interests == null
      ? {}
      : userData!.interests!.split(',').toSet());
      _prefs.setStringList('user_interests', _interests.toList());
    } 
    else {
      List<String>? savedList = _prefs.getStringList('user_interests');
      if(savedList != null) {
        _interests = savedList.toSet();
      }
    }

    //age range
    if(_prefs.getInt('min_age') == null || _prefs.getInt('max_age') == null) {
      _ageRange = RangeValues(userData?.minAgeRange == null ? 18 : userData!.minAgeRange!.toDouble(),
        userData?.maxAgeRange == null ? 30 : userData!.maxAgeRange!.toDouble());
      _prefs.setInt('min_age', _ageRange.start.round());
      _prefs.setInt('max_age',  _ageRange.end.round());
    } 
    else {
      int? min = _prefs.getInt('min_age');
      int? max = _prefs.getInt('max_age');
      _ageRange = RangeValues(min!.toDouble(), max!.toDouble());
    }
    
    //show out of age range
    if(_prefs.getBool('outOfRange') == null) {
      _showOutOfRange = userData?.showOutOfRange == null ? false : userData!.showOutOfRange!;
      _prefs.setBool('outOfRange', _showOutOfRange);
    }
    else {
      _showOutOfRange = _prefs.getBool('outOfRange')!;
    }
    
    //recommendation preference
    if(_prefs.getString('recommendationOpt') == null) {
      bool isBalanced = userData?.isBalanced ?? true;
      _currentOpt = isBalanced ? RecommendationPreference.balanced : RecommendationPreference.recentlyActive;
      _prefs.setString('recommendationOpt', _currentOpt.name);
    }
    else {
      String? savedValue = _prefs.getString('recommendationOpt');
      if(savedValue != null) {
        _currentOpt = RecommendationPreference.values.firstWhere(
          (e) => e.name == savedValue,
          orElse: () => RecommendationPreference.balanced
        );
      }
    }
    
    String langCode;
    if(_prefs.getString('language_code') == null) {
      langCode =  data.language!;
      _locale = Locale(langCode);
      _prefs.setString('language_code', data.language!);
    }
    else {
      langCode = _prefs.getString('language_code')!;
      _locale = Locale(langCode);

    }

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
      //does the os give permission
      bool osPermission = await checkNotificationPermission();
      _osPermission = osPermission;
      //if os and db return true then enable notifications else keep false
      if(osPermission && data.isNotificationsOn!) {
        pushNotifications = true;
        _prefs.setBool('notifications_enabled', true);
      }
      else {
        pushNotifications = false;
        _prefs.setBool('notifications_enabled', false);
      }
    }
    else {
      _osPermission = await checkNotificationPermission();
      if(_osPermission) {
        pushNotifications = _prefs.getBool('notifications_enabled') ?? false;
      }
      else {
        pushNotifications = false;
      }
      
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
    } catch (e) {
      _pushNotificationsEnabled = false;
    }

    notifyListeners();
  }

  //Theme change function
  void toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    await _prefs.setBool('isDark', isDark);
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
        await _prefs.setBool('notifications_enabled', value);
        _osPermission = true;
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

    await _prefs.setBool('isPhoneVerified', true);
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
  Future<void> _saveInterests() async {
    _prefs.setStringList('user_interests', _interests.toList());
    final String interestsString  = _interests.join(',');
    await ApiService.updateUserData(uid: FirebaseAuth.instance.currentUser!.uid, interests: interestsString);
  }

  //split range values to save them to disk
  Future<void> saveAgeRange(RangeValues values) async {
    _ageRange = values;
    _prefs.setInt('min_age', values.start.round());
    _prefs.setInt('max_age', values.end.round());
    notifyListeners();
    await ApiService.updateUserData(uid: FirebaseAuth.instance.currentUser!.uid, 
      minAgeRange: values.start.round(),
      maxAgeRange: values.end.round());
  }

  //store out of range switch state
  void storeShowOutOfRange(bool outOfRange) async {
    _showOutOfRange = outOfRange;
    _prefs.setBool('outOfRange', outOfRange);
    notifyListeners();
    await ApiService.updateUserData(uid: FirebaseAuth.instance.currentUser!.uid,
      showOutOfRange: _showOutOfRange);
  }

  //recommendation preference
  Future<void> changeRecommendationPreference(RecommendationPreference opt) async {
    _currentOpt = opt;
    notifyListeners();
    _prefs.setString('recommendationOpt', opt.name);
    await ApiService.updateUserData(uid: FirebaseAuth.instance.currentUser!.uid,
    isBalanced: _currentOpt == RecommendationPreference.balanced ? true : false);
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

  //does os give permission for notifications
  Future<bool> checkNotificationPermission() async {
    PermissionStatus status = await Permission.notification.status;

    if(status.isGranted) {
      return true;
    }
    else if(status.isDenied) {
      return false;
    }
    else if(status.isPermanentlyDenied) {
      return false;
    }
    return false;
  }
