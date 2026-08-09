//Manages local profile image handling as well as picking an image from users gallery
//Gets called strictly by the profile_provider.dart to handle pfp

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  //Function that uploads the image file in the firebase cloud and returns the unique url for it
  //Image is the image that will be uploaded to the cloud
  //Uid is the unique user identifier so postgres knows to which user to save the returned url
  static Future<String?> uploadImage(File image, String uid) async {
    try {
      //The adress in the cloud. Where the file will be stored in the cloud bucket
      final Reference storageRef = FirebaseStorage.instance
      .ref().child('profile_image/$uid.jpg');

      //Upload of the file to the cloud
      final UploadTask uploadTask = storageRef.putFile(image);
      //Pause until the file gets uploaded
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}