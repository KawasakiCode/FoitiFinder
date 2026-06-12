//Provider that loads the profile of the user (profile picture username, age)
//only used for profile related variables

import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/services/image_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

//Outcome of a profile picture update so the UI can give proper feedback.
//cancelled = user backed out of the picker (no error to show).
enum ProfilePictureUpdate { success, cancelled, failed }

class ProfileProvider extends ChangeNotifier {
  final SharedPreferences _prefs; 
  File? _tempprofileImage; //to preview updates and check for changes
  UserModel? _currentUser;
  bool isLoading = false; //flag to check for backend activity

  //The provider when initialized loads data from disk or if disk is empty loads null
  //Using this way we save the time of making a call to the db
  //99% of the time disk will be correct anyway
  ProfileProvider(this._prefs) {
    loadUser();
  }

  //image getter
  File? get tempProfileImage => _tempprofileImage;
  //user getter
  UserModel? get currentUser => _currentUser;

  //Load from disk
  Future<void> loadUser() async {
    //already have the user in memory (e.g. just registered during signup) ->
    //nothing to load, and crucially nothing to 404 on
    if (_currentUser != null) return;

    String? userJson = _prefs.getString('user_data');

    if(userJson != null) {
      try {
        Map<String, dynamic> userMap = jsonDecode(userJson);
        _currentUser = UserModel.fromJson(userMap);
      } catch (e) {
        _prefs.remove('user_data');
      }
    }
    else {
      final fbUser = FirebaseAuth.instance.currentUser;
      if(fbUser != null) {
        //await so currentUser is actually populated before callers read it
        //(SetupWrapper routes based on the return value of this)
        await fetchUserFromApi(fbUser.uid);
      }
    }
  }

  //Load user data from postgres database and also store them in prefs if empty or different
  Future<void> fetchUserFromApi(String uid) async {
    
    UserModel? user = await ApiService.getUserData(uid);

    if(user != null) {
      _currentUser = user;
      notifyListeners();

      await _prefs.setString('user_data', jsonEncode(user.toMap()));
    }
  }

  //Pick the image file, store it temporarily and upload it to cloud and get the url back.
  //Returns a result so the caller can show feedback instead of failing silently.
  Future<ProfilePictureUpdate> updateProfilePicture() async {
    File? file;
    try {
      file = await ImageService.pickImage();
    } catch (e) {
      //picker can throw (e.g. denied gallery permission)
      return ProfilePictureUpdate.failed;
    }
    //user cancelled the picker
    if (file == null) return ProfilePictureUpdate.cancelled;

    _tempprofileImage = file;
    notifyListeners();

    final String? uid = _currentUser?.uid;
    if (uid == null) {
      _tempprofileImage = null;
      notifyListeners();
      return ProfilePictureUpdate.failed;
    }

    try {
      final String? url = await ImageService.uploadImage(file, uid);
      //upload failed: drop the preview so the UI doesn't show an unsaved image
      if (url == null) {
        _tempprofileImage = null;
        notifyListeners();
        return ProfilePictureUpdate.failed;
      }

      await ApiService.updateUserData(uid: uid, imageUrl: url);
      //clear the temp preview before refreshing so the UI shows the saved url
      _tempprofileImage = null;
      updateLocalUser(imageUrl: url);
      return ProfilePictureUpdate.success;
    } catch (e) {
      //db update or upload threw, undo the preview and report failure
      _tempprofileImage = null;
      notifyListeners();
      return ProfilePictureUpdate.failed;
    }
  }

  //Register new user on sign up
  Future<void> registerUser({
    required String uid,
    required String username,
    required bool hasFinishedSetUp,
    required bool hasPhotos,
    required double score,
    String? fullName,
    String? bio,
    int? age,
    String? imageUrl,
    String? gender,
    int? minAgeRange,
    int? maxAgeRange,
    bool? showOutOfRange,
    bool? isBalanced,
    String? interests,
  }) async {
      isLoading = true;

      //Optimistically set the local user + cache BEFORE the backend round-trip,
      //so the auth router (SetupWrapper) immediately treats us as a valid,
      //logged-in user and doesn't sign us out while createUser is still in
      //flight (a GET would 404 until the POST commits).
      _currentUser = UserModel(
        uid: uid,
        username: username,
        fullName: fullName,
        hasFinishedSetUp: hasFinishedSetUp,
        score: score,
        bio: bio,
        age: age,
        imageUrl: imageUrl,
        gender: gender,
        minAgeRange: minAgeRange,
        maxAgeRange: maxAgeRange,
        showOutOfRange: showOutOfRange,
        isBalanced: isBalanced,
        interests: interests,
        hasPhotos: hasPhotos,
      );
      notifyListeners();
      await _prefs.setString('user_data', jsonEncode(_currentUser!.toMap()));

      try {
        await ApiService.createUser(
          uid: uid,
          username: username,
          hasFinishedSetUp: hasFinishedSetUp,
          score: score,
          bio: bio,
          fullName: fullName,
          age: age,
          imageUrl: imageUrl,
          gender: gender,
          minAgeRange: minAgeRange,
          maxAgeRange: maxAgeRange,
          showOutOfRange: showOutOfRange,
          isBalanced: isBalanced,
          interests: interests,
          hasPhotos: hasPhotos,
        );
      } catch (e) {
        //creation failed -> roll back the optimistic state; signUp deletes the
        //Firebase user and shows the error
        _currentUser = null;
        await _prefs.remove('user_data');
        notifyListeners();
        isLoading = false;
        rethrow;
      }

      isLoading = false;
  }

  //Update users data (sync with database)
  void updateLocalUser({
    String? username,
    String? fullName,
    String? bio,
    int? age,
    String? imageUrl,
    bool? hasFinishedSetUp,
    double? score,
    bool? hasPhotos,
  }) async {
    if(currentUser == null)return;

    _currentUser = UserModel(  
      uid: _currentUser!.uid,
      username: username ?? _currentUser!.username,
      fullName: fullName ?? _currentUser!.fullName,
      hasFinishedSetUp: hasFinishedSetUp ?? _currentUser!.hasFinishedSetUp,
      score: score ?? _currentUser!.score,
      hasPhotos: hasPhotos ?? _currentUser!.hasPhotos,
      bio: bio ?? _currentUser!.bio,
      age: age ?? _currentUser!.age,
      imageUrl: imageUrl ?? _currentUser!.imageUrl,
    );

    notifyListeners();

    await _prefs.setString('user_data', jsonEncode(_currentUser!.toMap()));
  }

  //Clear all data (used on logout)
  Future<void> clearData() async {
    _currentUser = null;
    _tempprofileImage = null;
    await _prefs.clear();
    notifyListeners();
  }
}