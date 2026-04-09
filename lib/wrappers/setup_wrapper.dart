//Decides what page to push depending if user finished the initial sign up setup or not
//gets called only by auth wrapper

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/main_screen.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/pages/auth_pages/login.dart';
import 'package:foitifinder/pages/sign_up_set_up/add_photos.dart';
import 'package:foitifinder/pages/sign_up_set_up/phone_verification_page.dart';
import 'package:foitifinder/pages/sign_up_set_up/set_up_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';

class SetupWrapper extends StatefulWidget {
  final User? firebaseUser;
  const SetupWrapper({super.key, required this.firebaseUser});

  @override
  State<SetupWrapper> createState() => _SetupWrapperState();
}


class _SetupWrapperState extends State<SetupWrapper> {
  UserModel? currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await fetchFromApi(widget.firebaseUser);

    if(mounted) {
      setState(() {
        currentUser = user;
        isLoading = false;
      },);
    }
  }
  
  Future<UserModel?> fetchFromApi(User? user) async {
    final userProvider = Provider.of<ProfileProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    await userProvider.loadUser();
    if (user != null) {
      await settingsProvider.fetchSettingsFromApi(user.uid);
    }

    return userProvider.currentUser; 
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      if (currentUser == null) {
        return const LoginPage();
      }
      bool hasFinishedSetUp = currentUser!.hasFinishedSetUp;
      bool hasPhone =
          widget.firebaseUser!.phoneNumber != null &&
          widget.firebaseUser!.phoneNumber!.isNotEmpty;
      //setup done completely, send to mainscreen
      if (hasFinishedSetUp && hasPhone) {
        return MainScreen(uid: widget.firebaseUser!.uid);
      }
      //setup not done completely, send to setup after phone number
      else if (hasPhone && !currentUser!.hasPhotos) {
        return const AddPhotos();
      }
      //setup not done completely, send to photos page since user has no photos
      else if (currentUser!.hasPhotos) {
        return const SetUpPage();
      }
      //setup not done neither phone, send to login
      else {
        return const PhoneVerificationPage();
      }
    } else {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
  }
}
