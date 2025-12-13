//provider that loads the profile of the user like profile picture username, age
//only used for profile related variables

import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart'; // To find the permanent folder
import 'package:path/path.dart' as path; // To get the filename
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileProvider extends ChangeNotifier { 
  final SharedPreferences _prefs;
  File? _profileImage;
  UserModel? _currentUser;
  String? _cloudUrl;

  //image getter
  File? get profileImage => _profileImage;
  //user getter
  UserModel? get currentUser => _currentUser;
  //cloud url getter for pfp
  String? get cloudUrl => _cloudUrl;

  //constructor
  ProfileProvider(this._prefs) {
    _loadFromDisk();
    _loadUserFromPrefs();
  }

//functions for profile image
  void _loadFromDisk() async {
    //used to ensure cloud block will run if any error to local block occurs
    bool localLoadSuccess = false;
    //get the path from prefs
    String? imagePath = _prefs.getString('user_image_path');

    if(imagePath != null) {
      final file = File(imagePath);
      if(file.existsSync()) {
        _profileImage = file;
        localLoadSuccess = true;
        notifyListeners();
      }
    }
    if(!localLoadSuccess) {
      UserModel? userData = await ApiService.getUserData(FirebaseAuth.instance.currentUser!.uid);
      if(userData.imageUrl != null) {
        _cloudUrl = userData.imageUrl;
        _prefs.setString("cloud_url", userData.imageUrl!);
        notifyListeners();
      }
    }
  }

  Future<void> pickAndSaveImage() async {
    //allows flutter to access the gallery and asks the android to open it
    final ImagePicker picker = ImagePicker();

    //file works only on android, ios, windows and mac while Xfile works on web too
    //await picker waits for the user to select an image
    final XFile? pickedFile = await picker.pickImage(  
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1000,
      maxHeight: 1000,
    );

    if(pickedFile == null)return;

    //first load the file and show it then store it and copy it
    File tempFile = File(pickedFile.path);
    _profileImage = tempFile;
    notifyListeners();

    //getApplicationDocumentsDirectory access the special folder made for the app 
    final directory = await getApplicationDocumentsDirectory();
    //basename keeps only the name of the file removing the rest of the path
    final String fileName = path.basename(pickedFile.path);
    //get the picked file and copy it to the special folder of the app to store
    final File localImage = await tempFile.copy('${directory.path}/$fileName');

    _profileImage = localImage;

    try {
      String? url = await uploadProfileImage();
      if(url != null) {
        String uid = FirebaseAuth.instance.currentUser!.uid;
        await ApiService.updateProfilePicture(uid, url);
        if(_currentUser != null) {
          UserModel updatedUser = UserModel(  
            uid: _currentUser!.uid,
            username: _currentUser!.username,
            fullName: _currentUser!.fullName,
            bio: _currentUser!.bio,
            age: _currentUser!.age,
            imageUrl: url,
          );

          await _prefs.setString('user_image_path', localImage.path);
          await _prefs.setString('user_data', jsonEncode(updatedUser.toMap()));
        }
      }
    } catch (e) {
      _profileImage = null;
    }

    //for later use
    // Future<void> clearImage() async {
    //   _profileImage = null;
    //   await _prefs.remove('user_image_path');
    //   notifyListeners();
    // }
  }
  //upload pfp to cloud
  Future<String?> uploadProfileImage() async {
    if(_profileImage == null)return null;

    try {
      //unique firebase token for every user. We will add that to the file path and url to ensure uniqueness
      final String uid = FirebaseAuth.instance.currentUser!.uid;
      //the adress in the cloud. Where the file will be stored in the cloud bucket
      final Reference storageRef = FirebaseStorage.instance.ref().child('profile_image/$uid.jpg');

      //upload of the file to the cloud
      final UploadTask uploadTask = storageRef.putFile(_profileImage!);
      //pause until the file gets uploaded
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

//functions for users upload to database
  Future<void> registerUser({
    required String uid,
    required String username,
    String? fullName,
    String? bio,
    int? age,
    String? imageUrl,
  }) async {
    try {
      await  ApiService.createUser(  
        uid: uid,
        username: username,
        bio: bio,
        fullName: fullName,
        age: age,
        imageUrl: imageUrl,
      );

      _currentUser = UserModel(  
        uid: uid,
        username: username,
        fullName: fullName,
        bio: bio,
        age: age,
        imageUrl: imageUrl,
      );

      String jsonString = jsonEncode(_currentUser!.toMap());
      _prefs.setString('user_data', jsonString);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void _loadUserFromPrefs() {
    if(_prefs.getString('user_data') != null) {
      Map<String, dynamic> decodedString = jsonDecode(_prefs.getString('user_data')!);
      _currentUser = UserModel.fromJson(decodedString);
    }
  }
}