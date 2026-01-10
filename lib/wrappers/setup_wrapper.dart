//decides what page to push depending if user finished the initial sign up setup or not
//gets called only by auth wrapper

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/main_screen.dart';
import 'package:foitifinder/pages/sign_up_set_up/add_photos.dart';
import 'package:foitifinder/pages/sign_up_set_up/phone_verification_page.dart';
import 'package:foitifinder/pages/sign_up_set_up/set_up_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:provider/provider.dart';

class SetupWrapper extends StatelessWidget {
  final User firebaseUser;

  const SetupWrapper({super.key, required this.firebaseUser});

  @override 
  Widget build(BuildContext context) {
    final userProvider = Provider.of<ProfileProvider>(context);
    final currentUser = userProvider.currentUser;

    bool hasFinishedSetUp = currentUser?.hasFinishedSetUp ?? false;
    bool hasPhone = firebaseUser.phoneNumber != null && firebaseUser.phoneNumber!.isNotEmpty;
    //setup done completely, send to mainscreen
    if(hasFinishedSetUp && hasPhone) {
      return MainScreen(uid: firebaseUser.uid);
    }
    //setup not done completely, send to setup after phone number
    else if(hasPhone && !currentUser!.hasPhotos) {
      return const AddPhotos();
    }
    //setup not done completely, send to photos page since user has no photos
    else if(currentUser!.hasPhotos) {
      return const SetUpPage();
    }
    //setup not done neither phone, send to login
    else{
      //to become login
      return const PhoneVerificationPage();
    }
  }
}