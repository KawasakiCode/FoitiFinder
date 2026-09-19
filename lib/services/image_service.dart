//Picks an image from the user's gallery, resized and compressed for upload.
//The upload itself is ApiService.uploadToFirebase, the same one Edit Profile
//uses: the profile picture is just photo 0.

import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ImageService {
  //The object that handles grabbing the file that the user selects
  static final ImagePicker _picker = ImagePicker();

  //The function that handles the picking and also reducing the image quality
  //To save size and upload times
  //Returns the path of the selected image
  static Future<File?> pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(  
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1000,
      maxHeight: 1000,
    );

    if(pickedFile == null)return null;
    return File(pickedFile.path);
  }
}
