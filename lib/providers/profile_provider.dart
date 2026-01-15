//provider that loads the profile of the user like profile picture username, age
//only used for profile related variables

//TODO we need a clear data function since it seems after log out some date from here are kept
//on the new account the logs in

import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/services/image_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider extends ChangeNotifier { 
  final SharedPreferences _prefs; 
  File? _tempprofileImage; //to preview updates and check for changes
  UserModel? _currentUser;

  //the provider when initialized loads data from disk or if disk is empty loads null
  //using this way we save the time of making a call to the db
  //99% of the time disk will be correct anyway
  ProfileProvider(this._prefs) {
    _loadUser();
  }

  //image getter
  File? get tempProfileImage => _tempprofileImage;
  //user getter
  UserModel? get currentUser => _currentUser;

  //function to load user from disk
  void _loadUser() {
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
      fetchUserFromApi(FirebaseAuth.instance.currentUser!.uid);
    }
  }

  //load user data from postgres database and also store them in prefs if empty
  Future<void> fetchUserFromApi(String uid) async {
    
    UserModel? user = await ApiService.getUserData(uid);

    if(user != null) {
      _currentUser = user;
      notifyListeners();

      await _prefs.setString('user_data', jsonEncode(user.toMap()));
    }
  }

  //pick the image file store it temporarily and upload it to cloud and get the url back
  Future<void> updateProfilePicture() async {
    //pick image
    File? file = await ImageService.pickImage();
    if(file == null)return;

    //store it temporarily and show it
    _tempprofileImage = file;
    notifyListeners();

    //upload it to cloud
    String? uid = _currentUser?.uid;
    if(uid != null) {
      String? url = await ImageService.uploadImage(file, uid);
      //update the db user data and local user data
      if(url != null) {
        await ApiService.updateUserData(uid: uid, imageUrl: url);
        updateLocalUser(imageUrl: url);
        //clean temp file
        _tempprofileImage = null;
      }
    }     
  }

  //register new user on sign up
  Future<void> registerUser({
    required String uid,
    required String username,
    required bool hasFinishedSetUp,
    required bool hasPhotos,
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
      //create new user in the database
      await  ApiService.createUser(  
        uid: uid,
        username: username,
        hasFinishedSetUp: hasFinishedSetUp,
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

      //store users data locally
      _currentUser = UserModel(  
        uid: uid,
        username: username,
        fullName: fullName,
        hasFinishedSetUp: hasFinishedSetUp,
        bio: bio,
        age: age,
        imageUrl: imageUrl,
        gender: gender,
        minAgeRange: minAgeRange,
        maxAgeRange: maxAgeRange,
        showOutOfRange: showOutOfRange,
        isBalanced: isBalanced,
        interests: interests,
        hasPhotos: hasPhotos
      );

      await _prefs.setString('user_data', jsonEncode(_currentUser!.toMap()));
      notifyListeners();
  }

  void updateLocalUser({
    String? username,
    String? fullName,
    String? bio,
    int? age,
    String? imageUrl,
    bool? hasFinishedSetUp,
    bool? hasPhotos,
  }) async {
    if(currentUser == null)return;

    _currentUser = UserModel(  
      uid: _currentUser!.uid,
      username: username ?? _currentUser!.username,
      fullName: fullName ?? _currentUser!.fullName,
      hasFinishedSetUp: hasFinishedSetUp ?? _currentUser!.hasFinishedSetUp,
      hasPhotos: hasPhotos ?? _currentUser!.hasPhotos,
      bio: bio ?? _currentUser!.bio,
      age: age ?? _currentUser!.age,
      imageUrl: imageUrl ?? _currentUser!.imageUrl,
    );

    notifyListeners();

    await _prefs.setString('user_data', jsonEncode(_currentUser!.toMap()));
  }
}