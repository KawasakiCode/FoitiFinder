//Email verification gate. Shown during onboarding (right after signup) and by
//the auth router (SetupWrapper) whenever the signed-in user's email is not yet
//verified. Polls Firebase live and also re-checks the instant the app resumes
//(e.g. after the user tapped the link in their mail app), then moves on to the
//photo step once verified.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/sign_up_set_up/instagram_page.dart';
import 'package:foitifinder/providers/notifications_provider.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:foitifinder/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/widgets/app_dialog.dart';

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
      //the first setup step; SetupWrapper keeps the same order on later launches
      MaterialPageRoute(builder: (_) => const InstagramPage()),
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
    final confirmed = await showAppDialog<bool>(
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
    final notifications = Provider.of<NotificationsProvider>(
      context,
      listen: false,
    );
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
      notifications.clear();
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
    final password = await showAppDialog<String>(
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
      child: GlassScaffold(
        appBar: AppBar(
          automaticallyImplyActions: true,
          title: Text(text.verifyYourEmail),
        ),
        body: CustomScrollView(
          slivers: [
            const SliverGlassBarInset(),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Entrance(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_outlined,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    //Verify email text
                    Entrance(
                      order: 1,
                      child: Text(
                        _isVerified ? text.mailVerified : text.verifyEmail,
                        style: headlineText(context),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    //User's email text
                    Entrance(
                      order: 2,
                      child: Text(
                        FirebaseAuth.instance.currentUser?.email ?? '',
                        textAlign: TextAlign.center,
                        style: mutedText(context),
                      ),
                    ),
                    //Confirmation that verification email was sent
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: _isEmailSent && !_isVerified
                          ? Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                child: Text(
                                  text.verificationEmailSent,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: 32),
                    //Sent verification email button — hidden once verified
                    if (!_isVerified)
                      Entrance(
                        order: 3,
                        child: PrimaryButton(
                          expand: false,
                          label: _canResend
                              ? text.sentVerificationEmail
                              : "${text.resendIn} ${_countdown}s",
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
                        ),
                      ),
                    const SizedBox(height: 16),
                    //Escape hatch: signed up with the wrong address — e.g. a
                    //typo that is actually another student's email. Deleting
                    //the unverified account frees that address so its real
                    //owner can sign up, instead of leaving it locked behind an
                    //account nobody can verify.
                    Entrance(
                      order: 4,
                      child: SpringPress(
                        child: TextButton(
                          onPressed: _confirmAndDelete,
                          style: TextButton.styleFrom(
                            foregroundColor: mutedInk(context),
                          ),
                          child: Text(text.backToLogin),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}