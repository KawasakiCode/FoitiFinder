//This file will only be called after the phone verified page of the
//initial sign up setup. The user should only see this file once on signup
//File is responsible for initial picking and uploading the user's photos
//to firebase cloud as well creating the links of the photos and
//saving them to the database

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/sign_up_set_up/set_up_page.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/photo_card.dart';
import 'package:image_picker/image_picker.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:foitifinder/widgets/primary_button.dart';
import 'package:foitifinder/theme/app_colors.dart';

class AddPhotos extends StatefulWidget {
  const AddPhotos({super.key});

  @override
  State<AddPhotos> createState() => _AddPhotos();
}

class _AddPhotos extends State<AddPhotos> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  bool _isLoading = false;
  //allow up to 6 photos
  //duplicates allowed
  final List<File?> _photos = List.filled(6, null);
  //set the image picker
  final ImagePicker _picker = ImagePicker();
  //bool to not allow the user to upload a photo when another
  //one is already uploading
  bool _isUploading = false;
  //slots that have already played their entrance; see Entrance.shouldPlay
  final Set<int> _enteredSlots = {};

  //Function to add a photo in the list
  Future<void> _pickImage(int index) async {
    //store the image in smaller resolution to improve loading times
    final XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 85,
      );
    } catch (e) {
      //picker can throw (e.g. denied gallery permission)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.errorOccured),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    //user cancelled the picker, nothing to do
    if (image == null) return;

    final String extension = image.path.split('.').last.toLowerCase();
    const List<String> allowedFormats = ['jpg', 'jpeg', 'png'];
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

    // Save the valid photo and compact the grid (no gaps)
    setState(() {
      _photos[index] = File(image!.path);

      List<File?> validPhotos = _photos.where((photo) => photo != null).toList();
      for (int i = 0; i < _photos.length; i++) {
        _photos[i] = i < validPhotos.length ? validPhotos[i] : null;
      }
    });
  }

  Future<void> _submitPhotos() async {
    setState(() {
      _isLoading = true;
    });
    //under the minimum: say so and stay here. The button is disabled too, so
    //this only catches a race (a photo removed while the upload starts).
    if (_photos.whereType<File>().length < kMinPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.addPhotoText),
          duration: Duration(seconds: 3),
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      List<Future<bool>> uploadTasks = [];

      for (int i = 0; i < _photos.length; i++) {
        if (_photos[i] != null) {
          final int order = i;
          //upload photo file to firebase cloud storage. Returns true only if
          //both the cloud upload AND the db record succeeded.
          Future<bool> uploadSinglePhoto = () async {
            final String? firebaseUrl = await ApiService.uploadToFirebase(
              _photos[order]!,
              uid,
            );
            if (firebaseUrl == null) return false;
            return await ApiService.uploadPhoto(
              uid: uid,
              photoUrl: firebaseUrl,
              displayOrder: order,
            );
          }(); //The parentheses trigger the function immediately

          uploadTasks.add(uploadSinglePhoto);
        }
      }

      final results = await Future.wait(uploadTasks);
      final int succeeded = results.where((ok) => ok).length;

      //nothing uploaded: keep the user here so they can retry instead of
      //silently moving on with zero photos
      if (succeeded == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(text.errorOccured),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return; //finally resets the loading flags
      }

      await ApiService.updateUserData(uid: uid, hasPhotos: true);

      //some (but not all) photos failed: let them continue but warn
      if (succeeded < results.length && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text.errorOccured),
            duration: Duration(seconds: 3),
          ),
        );
      }

      //if at least one photo uploaded send the user to the setup page
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const SetUpPage()));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.errorOccured),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      //unlock uploading stream
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(
        title: Text(text.uploadPhotos),
        automaticallyImplyLeading: true,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: GlassScroll(
          slivers: [
            //Text
            SliverStagger(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  text.addAtLeastPhotos(kMinPhotos),
                  style: mutedText(context),
                ),
              ],
            ),
            //The grid and photo placements
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.7,
                ),
                delegate: SliverChildBuilderDelegate(
                  childCount: 6,
                  (context, index) => Entrance(
                    key: ValueKey(index),
                    order: Entrance.orderFor(index),
                    shouldPlay: () => _enteredSlots.add(index),
                    child: _buildPhotoSlot(index),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      //the overlay does not reach the bottom bar, so it is held still here
      bottomBar: IgnorePointer(
        ignoring: _isLoading,
        child: PrimaryButton(
          label: text.submit,
          //greyed out until the minimum is met: a disabled button
          //explains the rule better than an error after the tap
          onPressed:
              _isUploading ||
                  _photos.whereType<File>().length < kMinPhotos
              ? null
              : _submitPhotos,
        ),
      ),
    );
  }

  //build the actual photo slot that goes inside the grid builder
  Widget _buildPhotoSlot(int index) {
    final photo = _photos[index];

    return Stack(
      children: [
        // 1. The Main Photo Slot
        Positioned.fill(
          child: SpringPress(
            child: GestureDetector(
              onTap: () => _pickImage(index),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.card,
                ),
                child: Crossfade(
                  child: photo != null
                      ? Image.file(
                          photo,
                          key: ValueKey(photo.path),
                          fit: BoxFit.cover,
                        )
                      : Center(
                          key: const ValueKey('empty'),
                          child: Icon(
                            Icons.add,
                            color: mutedInk(context),
                            size: 32,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),

        // 2. The Top-Left Remove Button (Only renders if a photo exists)
        if (photo != null)
          Positioned(
            top: 8,
            left: 8,
            child: SpringPress(
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
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
