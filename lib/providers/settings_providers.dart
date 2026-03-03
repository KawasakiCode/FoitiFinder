//The provider that loads and changes global settings like dark mode, language. 
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

  //The provider when initialized loads data from disk or if disk is empty loads the defaults
  //using this way we save the time of making a call to the db
  //99% of the time disk will be correct anyway
  SettingsProvider(this._prefs){
    _loadDefaults();
  }

  //State variables (private)
  ThemeMode _themeMode = ThemeMode.light;
  bool _likeNotificationsEnabled = false;
  bool _messageNotificationsEnabled = false;
  bool _isPhoneVerified = false;
  Set<String> _interests = {};
  RangeValues _ageRange = RangeValues(0, 0);
  bool _showOutOfRange = false;
  RecommendationPreference _currentOpt = RecommendationPreference.balanced;
  Locale _locale = const Locale('el');
  bool _osPermission = false;
  String _gender = "";

  //Getters
  ThemeMode get themeMode => _themeMode;
  bool get likeNotificationsEnabled => _likeNotificationsEnabled;
  bool get messageNotificationsEnabled => _messageNotificationsEnabled; 
  bool get isPhoneVerified => _isPhoneVerified;
  Set<String> get interests => _interests;
  RangeValues get ageRange => _ageRange;
  bool get showOutOfRange => _showOutOfRange;
  RecommendationPreference get currentOpt => _currentOpt;
  Locale get locale => _locale;
  bool get osPermission => _osPermission;
  String get gender => _gender;

  void _loadDefaults() {
    _themeMode = (_prefs.getBool('isDark') ?? false) ? ThemeMode.light : ThemeMode.dark;
    _likeNotificationsEnabled = (_prefs.getBool('like_notifications_enabled') ?? false) ? true : false;
    _messageNotificationsEnabled = (_prefs.getBool('message_notifications_enabled') ?? false) ? true : false;
    _locale = _prefs.getString('language') == 'en' ? Locale('en') : Locale('el');
    _ageRange = RangeValues(18, 30);
    _interests = {};
    _currentOpt = RecommendationPreference.balanced;
    _showOutOfRange = false;
    _isPhoneVerified = false;
    _gender = "";
  }

  Future<void> fetchSettingsFromApi(String uid) async {
    SettingsModel data = await ApiService.getUsersSettings(uid);
    UserModel? userData = await ApiService.getUserData(uid);
    //Theme  
    if(_prefs.getBool('isDark') == null) {
      bool isDark = data.isDark ?? false;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _prefs.setBool('isDark', isDark);
    }
    else {
      _themeMode = _prefs.getBool('isDark')! ? ThemeMode.dark : ThemeMode.light;
    }

    //Is phone verified
    _isPhoneVerified = _prefs.getBool('isPhoneVerified') ?? false;

    //Interests
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

    if(_prefs.getString('gender') == null) {
      _gender = userData?.gender ?? "";
      _prefs.setString('gender', _gender);
    } 
    else {
      _gender = _prefs.getString('gender') ?? "";
    }

    //Age range
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
    
    //Show out of age range
    if(_prefs.getBool('outOfRange') == null) {
      _showOutOfRange = userData?.showOutOfRange == null ? false : userData!.showOutOfRange!;
      _prefs.setBool('outOfRange', _showOutOfRange);
    }
    else {
      _showOutOfRange = _prefs.getBool('outOfRange')!;
    }
    
    //Recommendation preference
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
    
    //Language
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

    //Notifications
    bool likePushNotifications;
    bool messagePushNotifications;
    if(_prefs.getBool('like_notifications_enabled') == null) {
      SettingsModel data = await ApiService.getUsersSettings(FirebaseAuth.instance.currentUser!.uid);
      //Does the os give permission?
      bool osPermission = await checkNotificationPermission();
      _osPermission = osPermission;
      //If os and db return true then enable notifications else keep false
      if(osPermission && data.isLikeNotificationsOn! && data.isMessageNotificationsOn!) {
        likePushNotifications = true;
        messagePushNotifications = true;
        _prefs.setBool('like_notifications_enabled', true);
        _prefs.setBool('message_notifications_enabled', true);
      }
      else if(osPermission && data.isMessageNotificationsOn! && !data.isLikeNotificationsOn!) {
        messagePushNotifications = true;
        likePushNotifications = false;
        _prefs.setBool('message_notifications_enabled', true);
        _prefs.setBool('like_notifications_enabled', true);
      }
      else {
        likePushNotifications = false;
        messagePushNotifications = false;
        _prefs.setBool('like_notifications_enabled', false);
        _prefs.setBool('message_notifications_enabled', false);
      }
    }
    else {
      _osPermission = await checkNotificationPermission();
      if(_osPermission) {
        likePushNotifications = _prefs.getBool('like_notifications_enabled') ?? false;
        messagePushNotifications = _prefs.getBool('message_notifications_enabled') ?? false;
      }
      else {
        likePushNotifications = false;
        messagePushNotifications = false;
      }
      
    }
    //Firebase code to give permission for push notifications
    try{
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.getNotificationSettings();

      if(settings.authorizationStatus == AuthorizationStatus.authorized && likePushNotifications) {
        _likeNotificationsEnabled = true;
      }
      else if(settings.authorizationStatus == AuthorizationStatus.authorized && messagePushNotifications) {
        _messageNotificationsEnabled = true;
      }
      else {
        _likeNotificationsEnabled = false;
        _messageNotificationsEnabled = false;
      }
    } catch (e) {
      _likeNotificationsEnabled = false;
      _messageNotificationsEnabled = false;
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
  // Future<void> toggleNotifications(bool value) async {
  //   //when user first turns the switch to on the app asks for permissions
  //   if (value == true) {
  //     FirebaseMessaging messaging = FirebaseMessaging.instance;

  //     NotificationSettings settings = await messaging.requestPermission(  
  //       alert: true,
  //       badge: true,
  //       sound: true,
  //     );
  //     //If user accepts permissions they are enabled and switch stays on
  //     if(settings.authorizationStatus == AuthorizationStatus.authorized) {
  //       _likeNotificationsEnabled = true;
  //       _messageNotificationsEnabled = true;
  //       //Token to identify specific user to send push notifications
  //       //String? token = await messaging.getToken();
  //       await _prefs.setBool('notifications_enabled', value);
  //       _osPermission = true;
  //     }
  //     //If user declines then switch stays off and no notifications can be sent
  //     else {
  //       _likeNotificationsEnabled = false;
  //       _messageNotificationsEnabled = false;
  //     }
  //   }
  //   //If the switch is gets turned off stop sending notifications
  //   else {
  //     _likeNotificationsEnabled = false;
  //     _messageNotificationsEnabled = false;
  //   }
  //   await ApiService.updateUsersSettings(uid: FirebaseAuth.instance.currentUser!.uid, isLikeNotificationsOn: _likeNotificationsEnabled, isMessageNotificationsOn: _messageNotificationsEnabled);
  //   notifyListeners();
  // }

  //Only handles the OS permission
  Future<bool> _ensureOsPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      _osPermission = true;
      return true;
    } else {
      // User denied permissions in the OS settings
      _osPermission = false;
      return false;
    }
  }

  //Toggle likes notifications
  Future<void> toggleLikeNotifications(bool value) async {
    // If turning ON, we must check OS permission first
    if (value == true) {
      bool hasPermission = await _ensureOsPermission();
      if (!hasPermission) {
        // If OS says no, we force the switch back to off
        _likeNotificationsEnabled = false;
        notifyListeners();
        return; 
      }
    }

    // Update the specific variable
    _likeNotificationsEnabled = value;
    
    // Save to local prefs (optional, good for startup)
    await _prefs.setBool('like_notifications_enabled', value);

    // Sync with Database
    await ApiService.updateUsersSettings(uid: FirebaseAuth.instance.currentUser!.uid, isLikeNotificationsOn: _likeNotificationsEnabled);
    
    notifyListeners();
  }

  //Toggle message notifications
  Future<void> toggleMessageNotifications(bool value) async {
    // If turning ON, we must check OS permission first
    if (value == true) {
      bool hasPermission = await _ensureOsPermission();
      if (!hasPermission) {
        _messageNotificationsEnabled = false;
        notifyListeners();
        return;
      }
    }

    // Update the specific variable
    _messageNotificationsEnabled = value;

    // Save to local prefs
    await _prefs.setBool('message_notifications_enabled', value);

    // Sync with Database
    await ApiService.updateUsersSettings(uid: FirebaseAuth.instance.currentUser!.uid, isMessageNotificationsOn: _messageNotificationsEnabled);

    notifyListeners();
  }

  //Phone number logic
  void verifyPhone() async {
    _isPhoneVerified = true;
    notifyListeners();

    await _prefs.setBool('isPhoneVerified', true);
  }

  //Add or remove interests
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

  //Store interests into disk
  Future<void> _saveInterests() async {
    _prefs.setStringList('user_interests', _interests.toList());
    final String interestsString  = _interests.join(',');
    await ApiService.updateUserData(uid: FirebaseAuth.instance.currentUser!.uid, interests: interestsString);
  }

  //Split range values to save them to disk
  Future<void> saveAgeRange(RangeValues values) async {
    _ageRange = values;
    _prefs.setInt('min_age', values.start.round());
    _prefs.setInt('max_age', values.end.round());
    notifyListeners();
    await ApiService.updateUserData(uid: FirebaseAuth.instance.currentUser!.uid, 
      minAgeRange: values.start.round(),
      maxAgeRange: values.end.round());
  }

  //Store out of range switch state
  void storeShowOutOfRange(bool outOfRange) async {
    _showOutOfRange = outOfRange;
    _prefs.setBool('outOfRange', outOfRange);
    notifyListeners();
    await ApiService.updateUserData(uid: FirebaseAuth.instance.currentUser!.uid,
      showOutOfRange: _showOutOfRange);
  }

  //Recommendation preference
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

  //Clear all prefs for logout
  Future<void> clearData() async {
    await _prefs.clear();
    _loadDefaults();
    notifyListeners();
  }

  void changeGender(String gender) async {
    if(gender == "") {
      _gender = "";
    } else {
      _gender = gender;
    }
    notifyListeners();
    _prefs.setString('gender', _gender);
    await ApiService.updateUserData(uid: FirebaseAuth.instance.currentUser!.uid, gender: _gender);
  }

  //Does os give permission for notifications
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
}

  

  
