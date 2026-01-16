//this file will only be called after the phone verified page of the 
//initial sign up setup. The user should only see this file once on signup
//File is responsible for initial picking and uploading the user's photos
//to firebase cloud as well creating the links of the photos and 
//saving them to the database

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/pages/sign_up_set_up/set_up_page.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:image_picker/image_picker.dart';

class AddPhotos extends StatefulWidget {
  const AddPhotos({super.key});

  @override
  State<AddPhotos> createState() => _AddPhotos();
}

class _AddPhotos extends State<AddPhotos> {
  //allow up to 6 photos
  //duplicates allowed 
  final List<File?> _photos = List.filled(6, null);
  //set the image picker 
  final ImagePicker _picker = ImagePicker();
  //bool to not allow the user to upload a photo when another 
  //one is already uploading
  bool _isUploading = false;

  //function to add a photo in the list
  Future<void> _pickImage(int index) async {
    //store the image in smaller resolution to improve loading times
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85);
  
    if(image != null) {
      setState(() {
        _photos[index] = File(image.path);
      });
    }
  }

  Future<void> _submitPhotos() async {
    //if no photos in the list exit submit
    if(_photos.every((img) => img == null)) {
      ScaffoldMessenger.of(context).showSnackBar(  
        SnackBar(content: Text("Please add at least one photo")),
      );
      return;
    }

    //lock the uploading stream 
    setState(() => _isUploading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    
    try {
      for(int i = 0; i < _photos.length; i++) {
        if(_photos[i] != null) {
          //upload photo file to firebase cloud storage
          String? firebaseUrl = await ApiService.uploadToFirebase(_photos[i]!, uid);
          //if successful store the link to the file inside the database
          if(firebaseUrl != null) {
            await ApiService.uploadPhoto(  
              uid: uid,
              photoUrl: firebaseUrl,
              displayOrder: i,
            );
          }
        }
      }
      if(_photos.isNotEmpty) {
        await ApiService.updateUserData(
          uid: uid, 
          hasPhotos: true
        );
      }


      //if all successful send the user to the setup page to complete sign up
      if(mounted) {
        Navigator.of(context).pushReplacement(  
          MaterialPageRoute(builder: (_) => const SetUpPage()),
        );
      }
    } catch (e) {
      throw Exception("There was an error $e");
    } finally {
      //unlock uploading stream
      if(mounted) setState(() => _isUploading = false);
    }

  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold (
        appBar: AppBar(  
          title: Text("Upload Your Photos"),
          automaticallyImplyLeading: true,
        ),
        body: Column(  
          children: [
            //Text
            Padding(  
              padding: EdgeInsets.all(16),
              child: Text("Add at least one photo to continue",
              style: TextStyle(fontSize: 15)),
            ),
            //The grid and photo placements
            Expanded(  
              child: GridView.builder(  
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.7,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return _buildPhotoSlot(index);
                },
              ),
            ),
            Padding(  
              padding: const EdgeInsets.all(15),
              child: SizedBox(  
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitPhotos,
                  child: Text("Submit"),
                )
              )
            )
          ]
        )
      ),
    );
  }

  //build the actual photo slot that goes inside the grid builder
  Widget _buildPhotoSlot(int index) {
    final photo = _photos[index];

    return GestureDetector(  
      onTap: () => _pickImage(index),
      child: Container(  
        decoration: BoxDecoration(  
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: photo != null  
          ? ClipRRect(  
            borderRadius: BorderRadius.circular(10),
            child: Image.file(photo, fit: BoxFit.cover),
          )
          : const Center(  
            child: Icon(Icons.add, color: Colors.grey, size: 30),
          )
      ),
    );
  }
}