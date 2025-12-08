import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart'; // To find the permanent folder
import 'package:path/path.dart' as path; // To get the filename
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider extends ChangeNotifier { 
  final SharedPreferences _prefs;
  File? _profileImage;

  //image getter
  File? get profileImage => _profileImage;

  //constructor
  ProfileProvider(this._prefs) {
    _loadFromDisk();
  }

  void _loadFromDisk() {
    //get the path from prefs
    String? imagePath = _prefs.getString('user_image_path');

    if(imagePath != null) {
      final file = File(imagePath);
      if(file.existsSync()) {
        _profileImage = file;
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

    await _prefs.setString('user_image_path', localImage.path);

    Future<void> clearImage() async {
      _profileImage = null;
      await _prefs.remove('user_image_path');
      notifyListeners();
    }
  }
}