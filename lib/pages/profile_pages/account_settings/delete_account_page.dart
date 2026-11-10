//From this page the user can delete their account permanently.
//
//THE DELETION IS INSTANT AND THE COPY NOW SAYS SO. deleteAccountLongText used
//to promise a 10 day window in which signing in would recover the account,
//written against a grace period this comment said would be added later and
//which never was. So the app described a feature it did not have, on the one
//screen where being wrong is unrecoverable - and once the privacy statement
//and the account deletion page were published, it contradicted them too.
//
//If a grace period is ever built, the string is where it gets announced again.

//Request the user's password for 2 reasons:
//Security to prevent third party deleting someone's account
//Firebase sometime throws requires-recent-login exception which would
//force the user to log out and in again which is bad UX

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:foitifinder/constants/legal.dart';
import 'package:foitifinder/utils/legal_launcher.dart';
import 'package:foitifinder/providers/notifications_provider.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/app_dialog.dart';
import 'package:foitifinder/widgets/polish.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});
  
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  late final TextEditingController _passwordController;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void deleteUser() async {

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final notifications = Provider.of<NotificationsProvider>(
      context,
      listen: false,
    );

    final user = FirebaseAuth.instance.currentUser!;
    final password = _passwordController.text.trim();

    // Validate password
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.snackbarEnterPasswordToConfirm),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      if (!context.mounted) return;
      showAppDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: BusyIndicator(),
        ),
      );

      // Re-authenticate the user with their password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);


      // Delete user from database
      await ApiService.deleteUserData();

      // Delete the user account from Firebase Auth
      await user.delete();

      // Close loading indicator
      if (!mounted) return;
      Navigator.of(context).pop();

      // Navigate to login page and clear navigation stack
      // Clear user from SharedPreferences and Provider
      await settings.clearData();
      await profileProvider.clearData();
      notifications.clear();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.snackbarSuccessDeletion),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } on FirebaseAuthException catch (e) {
      // Close loading indicator if still showing
      if (!context.mounted) return;
      Navigator.of(context).pop();

      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = text.incorrectPassword;
          break;
        case 'invalid-credential':
          errorMessage = text.invalidPassword;
          break;
        case 'requires-recent-login':
          errorMessage = text.requiresRecentLogin;
          break;
        case 'user-not-found':
          errorMessage = text.userNotFound;
          break;
        case 'user-mismatch':
          errorMessage = text.credentialsDontMatchUser;
          break;
        default:
          errorMessage = '${text.generalError} ${e.message}';
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      // Close loading indicator if still showing
      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${text.unexpectedError} $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: PageAppBar(title: text.deleteAccount),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: GlassScroll(
          slivers: [
            SliverStagger(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                SurfaceCard(
                  child: Column(
                    children: [
                      Text(
                        text.sureDeleteAccount,
                        textAlign: TextAlign.center,
                        style: headlineText(context).copyWith(fontSize: 20),
                      ),
                      const Divider(height: 32),
                      Text(
                        text.deleteAccountLongText,
                        textAlign: TextAlign.center,
                        style: mutedText(context),
                      ),
                      const SizedBox(height: 16),
                      //Link text
                      Text.rich(
                        TextSpan(
                          text: text.readPolicy,
                          style: mutedText(context),
                          children: [
                            TextSpan(
                              text: text.privacyPolicy,
                              style: const TextStyle(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => openLegalDocument(
                                      context,
                                      LegalDocument.privacyStatement,
                                    ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      //Password field
                      TextFormField(
                        decoration: InputDecoration(
                          hintText: text.enterPassword,
                          suffixIcon: PasswordEye(
                            visible: _isPasswordVisible,
                            onTap: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                      const SizedBox(height: 8),
                      //Delete button
                      SpringPress(
                        child: TextButton(
                          onPressed: deleteUser,
                          child: Text(
                            text.deleteMyAccount,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
