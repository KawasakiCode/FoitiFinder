//Decides what page to push depending if user finished the initial sign up setup or not
//gets called only by auth wrapper

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/debug_flags.dart';
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
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    //CRITICAL path: load the profile (from disk cache, or the backend). Only
    //this is allowed to time out and decide whether we're really logged in.
    //A disk-cached user resolves instantly; only a cache miss touches the network.
    try {
      await profileProvider.loadUser().timeout(const Duration(seconds: 8));
    } catch (_) {}

    if (!mounted) return;

    final user = profileProvider.currentUser;

    //Genuinely no profile (cache miss AND backend unreachable) -> sign out.
    if (user == null) {
      await FirebaseAuth.instance.signOut();
      return; //authStateChanges rebuilds AuthWrapper -> LoginPage
    }

    //Settings are SECONDARY: fire-and-forget so a slow/booting backend can't
    //hang the load and sign a valid, cached user out (that was the bug). It
    //updates the theme/notifications in the background once it returns.
    if (widget.firebaseUser != null) {
      settingsProvider
          .fetchSettingsFromApi(widget.firebaseUser!.uid)
          .catchError((_) {});
    }

    setState(() {
      currentUser = user;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      if (currentUser == null) {
        return const LoginPage();
      }
      //TESTING: skip phone + photo onboarding and land on the homepage.
      if (kBypassOnboarding) {
        return MainScreen(uid: widget.firebaseUser!.uid);
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
