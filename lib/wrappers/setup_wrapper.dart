//Decides what page to push depending if user finished the initial sign up setup or not
//gets called only by auth wrapper

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/main_screen.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/pages/auth_pages/login.dart';
import 'package:foitifinder/pages/auth_pages/verify_email.dart';
import 'package:foitifinder/pages/sign_up_set_up/add_photos.dart';
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
  AppLocalizations get text => AppLocalizations.of(context)!;

  UserModel? currentUser;
  bool isLoading = true;
  //true when we could not reach the backend at all. Deliberately distinct from
  //"the backend told us this account does not exist" - see _loadData.
  bool loadError = false;

  //The signed-in user. FirebaseAuth.instance.currentUser can still be null for
  //a moment after startup while the SDK restores the session from disk, so fall
  //back to the user AuthWrapper already proved exists. Reading only the live
  //value made this branch flip at random: release builds start fast enough to
  //lose that race, take the wrong path, and sign a valid user out for good.
  User? get _fbUser => FirebaseAuth.instance.currentUser ?? widget.firebaseUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    //Email verification is mandatory, and an unverified user has nothing to
    //load anyway: every data endpoint is gated on a verified email.
    final fbUser = _fbUser;
    if (fbUser != null && !fbUser.emailVerified) {
      setState(() => isLoading = false);
      return;
    }

    //CRITICAL path: load the profile (from disk cache, or the backend).
    //A disk-cached user resolves instantly; only a cache miss touches the network.
    bool loadFailed = false;
    try {
      await profileProvider
          .loadUser(uid: fbUser?.uid)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      //timeout, offline, 401/403 or a 5xx: we do not KNOW whether the account
      //exists, which is a completely different thing from knowing it doesn't
      loadFailed = true;
    }

    if (!mounted) return;

    final user = profileProvider.currentUser;

    //Couldn't reach the backend -> keep the session and offer a retry. Signing
    //out here used to destroy a perfectly good login on any network blip or
    //Render cold start, and because signOut() clears the persisted session the
    //app could never recover from it on later launches.
    if (user == null && loadFailed) {
      setState(() {
        loadError = true;
        isLoading = false;
      });
      return;
    }

    //loadUser finished cleanly and still found nothing -> the backend answered
    //404, so this account really is gone (deleted or banned). Only this case
    //justifies signing out.
    if (user == null) {
      await FirebaseAuth.instance.signOut();
      return; //authStateChanges rebuilds AuthWrapper -> LoginPage
    }

    //Settings are SECONDARY: fire-and-forget so a slow/booting backend can't
    //hang the load. It updates the theme/notifications in the background once
    //it returns.
    if (fbUser != null) {
      settingsProvider.fetchSettingsFromApi(fbUser.uid).catchError((_) {});
    }

    setState(() {
      currentUser = user;
      loadError = false;
      isLoading = false;
    });
  }

  Future<void> _retry() async {
    setState(() {
      loadError = false;
      isLoading = true;
    });
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    //Backend unreachable: the user stays signed in and can try again, instead
    //of being bounced to the login page.
    if (loadError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(text.errorOccured, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _retry, child: Text(text.retry)),
              ],
            ),
          ),
        ),
      );
    }

    //Email verification is mandatory before any onboarding step, and it is
    //checked before the "no profile" branch: an unverified user may have no
    //backend row yet (or had it deleted mid-flow) and must still be able to
    //reach the gate to verify or delete their account.
    final fbUser = _fbUser;
    if (fbUser != null && !fbUser.emailVerified) {
      return const VerifyEmail();
    }
    if (currentUser == null) {
      return const LoginPage();
    }
    //Onboarding order (email verified -> photos -> profile setup).
    bool hasFinishedSetUp = currentUser!.hasFinishedSetUp;
    if (hasFinishedSetUp) {
      return MainScreen(uid: fbUser!.uid);
    }
    //no photos yet -> start with the photo step
    else if (!currentUser!.hasPhotos) {
      return const AddPhotos();
    }
    //has photos but hasn't finished the profile setup -> the setup step
    else {
      return const SetUpPage();
    }
  }
}
