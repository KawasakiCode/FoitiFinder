//The provider that loads and changes global settings like dark mode, language. 
//used only for settings within the settings page

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:foitifinder/models/settings_model.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

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
  Set<String> _preferredGender = {};
  RangeValues _ageRange = RangeValues(0, 0);
  Locale _locale = const Locale('el');
  bool _localeSwitching = false;
  bool _osPermission = false;
  String _gender = "";

  //Getters
  ThemeMode get themeMode => _themeMode;
  bool get likeNotificationsEnabled => _likeNotificationsEnabled;
  Set<String> get preferredGender => _preferredGender;
  RangeValues get ageRange => _ageRange;
  Locale get locale => _locale;
  //true while a language change is in flight, so main.dart can hold a curtain
  //over the rebuild instead of letting every string snap over at once
  bool get localeSwitching => _localeSwitching;
  bool get osPermission => _osPermission;
  String get gender => _gender;

  void _loadDefaults() {
    //isDark==true means DARK (matches toggleTheme + fetchSettingsFromApi);
    //default (no saved pref) is dark. This was previously inverted, which made
    //the app flash/stick in light mode for users who actually had dark on.
    _themeMode = (_prefs.getBool('isDark') ?? true) ? ThemeMode.dark : ThemeMode.light;
    _likeNotificationsEnabled = (_prefs.getBool('like_notifications_enabled') ?? false) ? true : false;
    //KEY NAME MATTERS: changeLanguage() and fetchSettingsFromApi() both write
    //'language_code'. Reading 'language' here meant this lookup ALWAYS missed,
    //so every launch started in Greek and then visibly flipped to the real
    //language once fetchSettingsFromApi returned.
    _locale = _prefs.getString('language_code') == 'en'
        ? const Locale('en')
        : const Locale('el');
    _ageRange = RangeValues(18, 30);
    _preferredGender = {};
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

    //Interests
    //NOTE: the prefs key changed with the column rename, so the first launch
    //after this ships finds nothing on disk and refetches from the API once.
    //Graceful - nothing is lost, it just costs one round trip.
    if(_prefs.getStringList('preferred_gender') == null) {
      _preferredGender =  (userData?.preferredGender == null
      ? {}
      : userData!.preferredGender!.split(',').toSet());
      _prefs.setStringList('preferred_gender', _preferredGender.toList());
    } 
    else {
      List<String>? savedList = _prefs.getStringList('preferred_gender');
      if(savedList != null) {
        _preferredGender = savedList.toSet();
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

    //Notifications
    bool likePushNotifications;
    if(_prefs.getBool('like_notifications_enabled') == null) {
      //Does the os give permission?
      bool osPermission = await checkNotificationPermission();
      _osPermission = osPermission;
      //If os and db return true then enable notifications else keep false
      if(osPermission && data.isLikeNotificationsOn!) {
        likePushNotifications = true;
        _prefs.setBool('like_notifications_enabled', true);
      }
      else {
        likePushNotifications = false;
        _prefs.setBool('like_notifications_enabled', false);
      }
    }
    else {
      _osPermission = await checkNotificationPermission();
      if(_osPermission) {
        likePushNotifications = _prefs.getBool('like_notifications_enabled') ?? false;
      }
      else {
        likePushNotifications = false;
      }
    }
    //Firebase code to give permission for push notifications
    try{
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.getNotificationSettings();

      if(settings.authorizationStatus == AuthorizationStatus.authorized && likePushNotifications) {
        _likeNotificationsEnabled = true;
      }
      else {
        _likeNotificationsEnabled = false;
      }
    } catch (e) {
      _likeNotificationsEnabled = false;
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
    notifyListeners();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'like_notifications': _likeNotificationsEnabled,
    });
    
    // Save to local prefs (optional, good for startup)
    await _prefs.setBool('like_notifications_enabled', value);

    // Sync with Database
    await ApiService.updateUsersSettings(uid: FirebaseAuth.instance.currentUser!.uid, isLikeNotificationsOn: _likeNotificationsEnabled);
  }

  //Add or remove a gender from the preference
  void addRemovePreferredGender(String gender, {bool saveToDb = true}) {
    if(_preferredGender.contains(gender)) {
      _preferredGender.remove(gender);
    }
    else {
      _preferredGender.add(gender);
    }
    notifyListeners();
    if(saveToDb) {
      _savePreferredGender();
    }
  }

  //Store the gender preference on disk and in the database
  Future<void> _savePreferredGender() async {
    _prefs.setStringList('preferred_gender', _preferredGender.toList());
    final String joined  = _preferredGender.join(',');
    await ApiService.updateUserData(uid: FirebaseAuth.instance.currentUser!.uid, preferredGender: joined);
  }

  //Split range values to save them to disk
  Future<void> saveAgeRange(RangeValues values, {bool saveToDb = true}) async {
    _ageRange = values;
    if(saveToDb) {
       _prefs.setInt('min_age', values.start.round());
      _prefs.setInt('max_age', values.end.round());
      notifyListeners();
      await ApiService.updateUserData(uid: FirebaseAuth.instance.currentUser!.uid, 
        minAgeRange: values.start.round(),
        maxAgeRange: values.end.round());
    } 
    else {
      notifyListeners();
    }    
  }

  //Changing the locale rebuilds MaterialApp, so EVERY string on screen swaps in
  //a single frame. Done bare that reads as a violent flicker - text changes and
  //layouts jump at the same instant with nothing to explain it.
  //
  //So: fade a curtain in, swap the locale while it is opaque, fade it back out.
  //The strings still change instantly, but the change happens where the eye
  //cannot see it and the app appears to settle into the new language.
  //
  //A curtain rather than an AnimatedSwitcher on the whole app: switching a
  //keyed subtree at the root would rebuild the Navigator and throw away the
  //navigation stack, dumping the user out of Settings.
  static const Duration localeFadeDuration = Duration(milliseconds: 160);

  Future<void> changeLanguage(String languageCode) async {
    //already in this language: a full app rebuild and an API call for nothing
    if (_locale.languageCode == languageCode) return;

    _localeSwitching = true;
    notifyListeners();
    //let the curtain actually reach full opacity before anything changes
    await Future.delayed(localeFadeDuration);

    _locale = Locale(languageCode);
    notifyListeners();
    //one frame for the rebuilt tree to lay out under the curtain, so the fade
    //out never reveals a half-painted screen
    await Future.delayed(const Duration(milliseconds: 32));

    _localeSwitching = false;
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

  void changeGender(String gender, {bool saveToDb = true}) async {
    if(gender == "") {
      _gender = "";
    } else {
      _gender = gender;
    }
    if(saveToDb) {
      notifyListeners();
      _prefs.setString('gender', _gender);
      await ApiService.updateUserData(uid: FirebaseAuth.instance.currentUser!.uid, gender: _gender);
    } else {
      notifyListeners();
    }
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

  Future<void> clearSkipOnSetUp() async {
    _ageRange = RangeValues(18, 30);
    _preferredGender = {};
    _gender = "";
    notifyListeners();
  }

  Future<void> confirmOnSetUp() async {
    changeGender(_gender);
    _savePreferredGender();
    saveAgeRange(_ageRange);
  }
}

  

  
