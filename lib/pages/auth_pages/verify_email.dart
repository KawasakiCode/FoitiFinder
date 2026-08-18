//Email verification gate. Shown during onboarding (right after signup) and by
//the auth router (SetupWrapper) whenever the signed-in user's email is not yet
//verified. Polls Firebase live and also re-checks the instant the app resumes
//(e.g. after the user tapped the link in their mail app), then moves on to the
//photo step once verified.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/sign_up_set_up/add_photos.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';
import 'package:provider/provider.dart';

class VerifyEmail extends StatefulWidget {
  const VerifyEmail({super.key});

  @override
  State<VerifyEmail> createState() => _VerifyEmailState();
}

class _VerifyEmailState extends State<VerifyEmail> with WidgetsBindingObserver {
  AppLocalizations get text => AppLocalizations.of(context)!;

  bool _isEmailSent = false;
  bool _isLoading = false;

  Timer? _timer;
  int _countdown = 60;
  bool _canResend = true;

  //Live-verification polling: reload() pulls the latest emailVerified flag from
  //Firebase's servers, so the screen flips the instant the user taps the link
  //in their inbox — no manual refresh, no re-opening the page.
  Timer? _pollTimer;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    //check once immediately (covers the already-verified case), then poll
    _checkVerified();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkVerified(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    //The user likely just came back from their mail app after tapping the
    //verification link — re-check now instead of waiting for the next poll tick.
    if (state == AppLifecycleState.resumed) {
      _checkVerified();
    }
  }

  //Ask Firebase for the freshest user state and flip the UI when verified.
  Future<void> _checkVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isVerified) return;

    try {
      await user.reload();
    } catch (_) {
      //transient network error — the next tick retries
      return;
    }

    final refreshed = FirebaseAuth.instance.currentUser;
    if (!mounted || !(refreshed?.emailVerified ?? false)) return;

    //set the guard before the await so a concurrent poll/resume tick can't
    //double-navigate while the token refresh is in flight
    _isVerified = true;
    _pollTimer?.cancel();
    //force a token refresh so the verified claim propagates to the rest of the
    //app/backend, not just this screen's cached flag
    try {
      await refreshed!.getIdToken(true);
    } catch (_) {}
    if (!mounted) return;

    //Verified — continue onboarding at the photo step. Uses pushReplacement so
    //the user can't navigate back into the verification gate.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AddPhotos()),
    );
  }

  void _startTimer() {
    setState(() {
      _countdown = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  //The escape button is destructive now, so confirm before deleting.
  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(text.sureDeleteAccount),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(text.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              text.deleteMyAccount,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  //Delete the unverified account so its email is freed (a mistyped address may
  //belong to a real student who'd otherwise be locked out by "email already in
  //use"). Deletes the Firebase user, wipes cached profile/settings, and the auth
  //router then drops back to login. Re-auths first if the session is stale.
  Future<void> _deleteAccount() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      try {
        await ApiService.deleteUserData();
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code != 'requires-recent-login') rethrow;
        //stale login — re-authenticate with the password, then retry delete
        final password = await _promptPassword();
        if (password == null || password.isEmpty) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(cred);
        await user.delete();
      }

      //clear cached profile/settings so a later login can't read stale data
      await settings.clearData();
      await profileProvider.clearData();
      //authStateChanges -> AuthWrapper -> LoginPage (this page is its content)
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.errorOccured),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  //Prompt for the account password to re-authenticate before deletion.
  Future<String?> _promptPassword() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(text.securityCheck),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: text.password,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(text.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(text.confirm),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyActions: true,
          title: Text(text.verifyYourEmail),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //Verify email text
              Padding(
                padding: EdgeInsets.only(left: 10, right: 10),
                child: Text(
                  _isVerified ? text.mailVerified : text.verifyEmail,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 5),
              //User's email text
              Text(
                FirebaseAuth.instance.currentUser?.email ?? '',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              if (_isEmailSent && !_isVerified)
                //Confirmation that verification email was sent
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 5),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 15),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      text.verificationEmailSent,
                      style: TextStyle(color: Colors.green[800]),
                    ),
                  ),
                ),
              //Sent verification email button — hidden once verified
              if (!_isVerified)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: TextButton(
                  onPressed: !_canResend
                      ? null
                      : () async {
                          setState(() {
                            //lock the button so if the user spams it it doesnt sent more emails
                            _isLoading = true;
                            _canResend = false;
                          });

                          try {
                            await FirebaseAuth.instance.currentUser?.sendEmailVerification();

                            if(!mounted)return;
                            setState(() {
                              _isEmailSent = true;
                            });

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(text.snackbarSuccessVerifyEmail),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 3),
                              ),
                            );

                            _startTimer();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(text.snackbarFailedVerifyEmail),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 3),
                              ),
                            );
                            //re-enable the button so the user can retry,
                            //otherwise it stays disabled with no timer running
                            setState(() {
                              _canResend = true;
                            },);
                          } finally {
                            setState(() {
                              //unlock button
                              _isLoading = false;
                            });
                          }
                        },
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _canResend
                        ? text.sentVerificationEmail
                        : "${text.resendIn} ${_countdown}s",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(height: 20),
              //Escape hatch: signed up with the wrong address — e.g. a typo that
              //is actually another student's email. Deleting the unverified
              //account frees that address so its real owner can sign up, instead
              //of leaving it locked behind an account nobody can verify.
              TextButton(
                onPressed: _confirmAndDelete,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  textStyle: TextStyle(fontSize: 14),
                ),
                child: Text(text.backToLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}