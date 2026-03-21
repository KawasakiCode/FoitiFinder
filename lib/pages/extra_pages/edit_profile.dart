//Edit profile page where user can change the following:
//email, bio, age, fullName, username, photos

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/photos_model.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _ageController;
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  bool _allowExit = false;

  //allow up to 6 photos
  //duplicates allowed
  final List<File?> _photos = List.filled(6, null);
  final ImagePicker _picker = ImagePicker();
  late final text = AppLocalizations.of(context)!;

  bool _isLoading = false;

  @override
  //grab existing data from firebase and provider(database)
  void initState() {
    super.initState();
    final user = Provider.of<ProfileProvider>(
      context,
      listen: false,
    ).currentUser!;
    final firebaseUser = FirebaseAuth.instance.currentUser!;

    _usernameController = TextEditingController(text: user.username);
    _bioController = TextEditingController(text: user.bio ?? "");
    _ageController = TextEditingController(
      text: user.age != null ? user.age.toString() : "",
    );
    _fullNameController = TextEditingController(text: user.fullName ?? "");
    _emailController = TextEditingController(text: firebaseUser.email ?? "");

    _refreshFirebaseUser();

    if (user.hasPhotos) {
      _getUserPhotos();
    }
  }

  Future<void> _getUserPhotos() async {
    try {
      List<PhotosModel> backendPhotos = await ApiService.getPhotos(
        FirebaseAuth.instance.currentUser!.uid,
      );
      for (int i = 0; i < backendPhotos.length; i++) {
        if (i >= 6) break;
        File file = await urlToFile(backendPhotos[i].photoUrl);

        if (mounted) {
          setState(() {
            _photos[i] = file;
          });
        }
      }
    } catch (e) {
      throw Exception("Failed to fetch photo from db $e");
    }
  }

  //download and save actual photo file
  Future<File> urlToFile(String imageUrl) async {
    final directory = await getTemporaryDirectory();
    final filename = path.basename(imageUrl);
    final file = File('${directory.path}/$filename');

    if (await file.exists()) {
      return file;
    }
    final response = await http.get(Uri.parse(imageUrl));

    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  //refresh firebase to show possibly updated email
  Future<void> _refreshFirebaseUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();

        final freshUser = FirebaseAuth.instance.currentUser;

        if (mounted &&
            freshUser != null &&
            freshUser.email != _emailController.text) {
          _emailController.text = freshUser.email!;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  //authenticate the user in case requires-recent-login exception happens
  Future<String?> _askForPassword() async {
    final text = AppLocalizations.of(context)!;

    //show a dialog to grab users password
    String? password;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(text.securityCheck),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text.confirmPassword),
              const SizedBox(height: 10),
              TextField(
                obscureText: true,
                onChanged: (value) => password = value,
                decoration: InputDecoration(
                  labelText: text.password,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(text.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, password),
              child: Text(text.confirm),
            ),
          ],
        );
      },
    );
  }

  //save new profile data to db and exit edit profile page
  Future<void>? _saveAndExit() async {
    final text = AppLocalizations.of(context)!;

    Map<String, dynamic> updatePayload = {};

    // final profileProvider = Provider.of<ProfileProvider>(
    //   context,
    //   listen: false,
    // );
    // final user = profileProvider.currentUser!;
    // final firebaseUser = FirebaseAuth.instance.currentUser!;

    // String? newUsername;
    // String? newBio;
    // String? newFullName;
    // int? newAge;
    // String? newEmail;

    // //check which variables changed
    // if (_usernameController.text != user.username) {
    //   newUsername = _usernameController.text;
    // }
    // if (_emailController.text != firebaseUser.email) {
    //   newEmail = _emailController.text;
    // }
    // if (_bioController.text != user.bio) {
    //   newBio = _bioController.text;
    // }
    // if (_fullNameController.text != user.fullName) {
    //   newFullName = _fullNameController.text;
    // }
    // if (_ageController.text != user.age.toString() &&
    //     _ageController.text.isNotEmpty) {
    //   newAge = int.tryParse(_ageController.text);
    // }

    // //check if something changed at all
    // if (newUsername != null ||
    //     newBio != null ||
    //     newAge != null ||
    //     newFullName != null) {
    //   await ApiService.updateUserData(
    //     uid: user.uid,
    //     username: newUsername,
    //     bio: newBio,
    //     age: newAge,
    //     fullName: newFullName,
    //   );
    // }

    // //change email
    // if (_emailController.text != firebaseUser.email &&
    //     _emailController.text.isNotEmpty) {
    //   try {
    //     await firebaseUser.verifyBeforeUpdateEmail(_emailController.text);

    //     if (mounted) {
    //       ScaffoldMessenger.of(context).showSnackBar(
    //         SnackBar(
    //           content: Text("${text.verifySend} $newEmail. ${text.checkInbox}"),
    //           duration: const Duration(seconds: 5),
    //         ),
    //       );
    //     }
    //   } on FirebaseAuthException catch (e) {
    //     if (e.code == "requires-recent-login") {
    //       String? password = await _askForPassword();
    //       if (password != null && password.isNotEmpty) {
    //         try {
    //           AuthCredential credential = EmailAuthProvider.credential(
    //             email: firebaseUser.email!,
    //             password: password,
    //           );

    //           await firebaseUser.reauthenticateWithCredential(credential);
    //           await firebaseUser.verifyBeforeUpdateEmail(_emailController.text);
    //           if (mounted) {
    //             ScaffoldMessenger.of(context).showSnackBar(
    //               SnackBar(
    //                 content: Text(
    //                   "${text.verifySend} $newEmail. ${text.checkInbox}",
    //                 ),
    //                 duration: const Duration(seconds: 5),
    //               ),
    //             );
    //           }
    //         } catch (reAuthError) {
    //           if (mounted) {
    //             ScaffoldMessenger.of(context).showSnackBar(
    //               SnackBar(
    //                 content: Text("${text.securityCheckFailed} $reAuthError"),
    //                 duration: const Duration(seconds: 2),
    //               ),
    //             );
    //             return;
    //           }
    //         }
    //       }
    //     }
    //   } catch (e) {
    //     if (mounted) {
    //       ScaffoldMessenger.of(context).showSnackBar(
    //         SnackBar(
    //           content: Text("${text.failedVerifyEmail} $e"),
    //           duration: const Duration(seconds: 2),
    //         ),
    //       );
    //     }
    //   }
    // }
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final user = profileProvider.currentUser!;
    final firebaseUser = FirebaseAuth.instance.currentUser!;

    // 1. THE REQUIRED FIELDS SHIELD
    // If they are completely empty, block the save, show a warning, and throw to stop navigation.
    if (_usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              text.emptyFields,
            ), // Add to your translation file
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      throw Exception('Validation failed: Required fields cannot be empty');
    }

    // 2. THE REGEX GATEKEEPERS
    final RegExp nameRegExp = RegExp(r"^(?=.*[a-zA-Z])[a-zA-Z\s\-']+$");
    final RegExp usernameRegExp = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_]{2,19}$');
    final RegExp emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (_fullNameController.text.isNotEmpty &&
        !nameRegExp.hasMatch(_fullNameController.text.trim())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text.fullNameRestriction),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      throw Exception('Validation failed: Invalid name format');
    }

    if (!usernameRegExp.hasMatch(_usernameController.text.trim())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text.usernameRestrictions),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      throw Exception('Validation failed: Invalid username format');
    }

    if (!emailRegExp.hasMatch(_emailController.text.trim())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text.invalidEmail),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      throw Exception('Validation failed: Invalid email format');
    }

    // 3. TRACKING CHANGES & GHOST DATA FIX
    String? newUsername;
    String? newBio;
    String? newFullName;
    int? newAge;
    String? newEmail;

    if (_usernameController.text.trim() != user.username) {
      updatePayload['username'] = _usernameController.text.trim();
      newUsername = _usernameController.text.trim();
    }
    if (_emailController.text.trim() != firebaseUser.email) {
      newEmail = _emailController.text.trim();
    }

    if (_bioController.text != (user.bio ?? "")) {
      updatePayload['bio'] = _usernameController.text.trim();
      newBio = _bioController.text;
    }
    if (_fullNameController.text.trim() != (user.fullName ?? "")) {
      updatePayload['full_name'] = _usernameController.text.trim();
      newFullName = _fullNameController.text.trim();
    }

    String currentAgeStr = (user.age != null && user.age != 0)
        ? user.age.toString()
        : "";
    if (_ageController.text != currentAgeStr) {
      if (_ageController.text.isEmpty) {
        newAge = null;
      } else {
        newAge = int.tryParse(_ageController.text);
      }
      updatePayload['age'] = _usernameController.text.trim();
      if(newAge != null && (newAge > 100 || newAge < 18)) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(text.invalidAge), // Add to translations
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );          
        }
        throw Exception('Validation failed: Age exceeds limit');
      }

    }

    // 4. DATABASE UPDATE
    if (newUsername != null ||
        newBio != null ||
        newAge != null ||
        newFullName != null) {
      await ApiService.updateUserData(
        uid: user.uid,
        updates: updatePayload,
      );
    }

    // 5. EMAIL CHANGE (Firebase Auth)
    if (newEmail != null) {
      try {
        await firebaseUser.verifyBeforeUpdateEmail(
          _emailController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${text.verifySend} $newEmail. ${text.checkInbox}"),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == "requires-recent-login") {
          String? password = await _askForPassword();
          if (password != null && password.isNotEmpty) {
            try {
              AuthCredential credential = EmailAuthProvider.credential(
                email: firebaseUser.email!,
                password: password,
              );

              await firebaseUser.reauthenticateWithCredential(credential);
              await firebaseUser.verifyBeforeUpdateEmail(
                _emailController.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "${text.verifySend} $newEmail. ${text.checkInbox}",
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            } catch (reAuthError) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${text.securityCheckFailed} $reAuthError"),
                    duration: const Duration(seconds: 3),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              throw Exception(
                'Reauthentication failed',
              ); // Added throw to stop navigation on failure
            }
          } else {
            throw Exception(
              'Password required for email change',
            ); // Added throw if they cancel password prompt
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("${text.failedVerifyEmail} $e"),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.red,
              ),
            );
          }
          throw Exception('Email verification failed');
        }
      }
    }

    //update Provider
    profileProvider.updateLocalUser(
      username: newUsername,
      fullName: newFullName,
      bio: newBio,
      age: newAge,
    );
    try {
      await _submitPhotos();

      if (mounted) {
        setState(() {
          _allowExit = true;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allowExit = true;
        });
      }
    }
  }

  //Function to add a photo in the list
  Future<void> _pickImage(int index) async {
    //store the image in smaller resolution to improve loading times
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final String extension = image.path.split('.').last.toLowerCase();
      final List<String> allowedFormats = ['jpg', 'jpeg', 'png'];

      if (!allowedFormats.contains(extension)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text.unsupportedFileType),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    if (image != null) {
      setState(() {
        _photos[index] = File(image.path);
      });
    }

    // If the file is valid, save it and compact the grid
    setState(() {
      // 1. Put the new photo into the tapped slot
      _photos[index] = File(image!.path);

      // 2. Gather all photos that currently exist in the array
      List<File?> validPhotos = _photos
          .where((photo) => photo != null)
          .toList();

      // 3. Re-deal them left-to-right to eliminate any gaps
      for (int i = 0; i < _photos.length; i++) {
        if (i < validPhotos.length) {
          _photos[i] = validPhotos[i]; // Fill front slots with photos
        } else {
          _photos[i] = null; // Fill remaining back slots with null
        }
      }
    });
  }

  Future<void> _submitPhotos() async {
    setState(() {
      _isLoading = true;
    });
    //if no photos in the list exit submit
    if (_photos.every((img) => img == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.addPhotoText),
          duration: Duration(seconds: 3),
        ),
      );
      setState(() {
        _isLoading = false;
      });
      throw Exception("Validation failed: no photos");
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      List<Future<void>> uploadTasks = [];

      for (int i = 0; i < _photos.length; i++) {
        if (_photos[i] != null) {
          //upload photo file to firebase cloud storage
          Future<void> uploadSinglePhoto = () async {
            String? firebaseUrl = await ApiService.uploadToFirebase(
              _photos[i]!,
              uid,
            );

            if (firebaseUrl != null) {
              await ApiService.uploadPhoto(
                uid: uid,
                photoUrl: firebaseUrl,
                displayOrder: i,
              );
            }
          }(); //The parentheses trigger the function immediately

          uploadTasks.add(uploadSinglePhoto);
        }
      }

      await Future.wait(uploadTasks);
      if (_photos.isNotEmpty) {
        await ApiService.updateUserData(uid: uid, hasPhotos: true);
      }

      //sent the request to the ai model to give the user a score
      await ApiService.giveUserScore(uid);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.errorOccured),
          duration: Duration(seconds: 3),
        ),
      );
      rethrow;
    } finally {
      //unlock uploading stream
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: _allowExit,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _saveAndExit();
        },
        child: SafeArea(
          child: LoadingOverlay(
            isLoading: _isLoading,
            child: Scaffold(
              appBar: AppBar(
                title: Text(text.editProfile),
                automaticallyImplyLeading: true,
              ),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 10,
                    left: 10,
                    right: 10,
                    bottom: 10,
                  ),
                  child: Column(
                    spacing: 20,
                    children: [
                      //GridView builder for the 6 photo slots
                      GridView.builder(
                        padding: const EdgeInsets.all(10),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                      //Username TextField
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(labelText: text.username),
                      ),
                      //Email TextField
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(labelText: text.email),
                      ),
                      //FullName TextField
                      TextField(
                        controller: _fullNameController,
                        decoration: InputDecoration(labelText: text.fullName),
                      ),
                      //Age TextField
                      TextField(
                        controller: _ageController,
                        decoration: InputDecoration(labelText: text.age),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      //Bio TextField
                      TextField(
                        controller: _bioController,
                        decoration: InputDecoration(labelText: "Bio"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  //build the actual photo slot that goes inside the grid builder
  // Widget _buildPhotoSlot(int index) {
  //   final photo = _photos[index];

  //   return GestureDetector(
  //     onTap: () => _pickImage(index),
  //     child: Container(
  //       decoration: BoxDecoration(
  //         color: Colors.grey[200],
  //         borderRadius: BorderRadius.circular(10),
  //       ),
  //       child: photo != null
  //           ? ClipRRect(
  //               borderRadius: BorderRadius.circular(10),
  //               child: Image.file(photo, fit: BoxFit.cover),
  //             )
  //           : const Center(
  //               child: Icon(Icons.add, color: Colors.grey, size: 30),
  //             ),
  //     ),
  //   );
  // }

  //build the actual photo slot that goes inside the grid builder
  Widget _buildPhotoSlot(int index) {
    final photo = _photos[index];

    return Stack(
      clipBehavior:
          Clip.none, // Allows the button to slightly overhang the edge
      children: [
        // 1. The Main Photo Slot
        Positioned.fill(
          child: GestureDetector(
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
                    ),
            ),
          ),
        ),

        // 2. The Top-Left Remove Button (Only renders if a photo exists)
        if (photo != null)
          Positioned(
            top: -5,
            left: -5,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  // 1. Set the removed photo's slot to null
                  _photos[index] = null;

                  // 2. Gather all the photos that are still left
                  List<File?> remainingPhotos = _photos
                      .where((photo) => photo != null)
                      .toList();

                  // 3. Re-deal them into the fixed array from left to right
                  for (int i = 0; i < _photos.length; i++) {
                    if (i < remainingPhotos.length) {
                      _photos[i] =
                          remainingPhotos[i]; // Fill with remaining photos
                    } else {
                      _photos[i] = null; // Fill the rest with empty slots
                    }
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }
}
