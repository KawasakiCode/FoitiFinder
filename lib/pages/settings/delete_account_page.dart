//From this page the user can delete their account permanently
//As of now the deletion is instant
//Later a grace period of 10 days will be added in case the user changes 
//their mind or deleted accidenticaly

//Request the user's password for 2 reasons:
//Security to prevent third party deleting someone's account
//Firebase sometime throws requires-recent-login exception which would
//force the user to log out and in again which is bad UX

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});
  
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
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

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(text.deleteAccount),
        automaticallyImplyLeading: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 25,
              right: 25,
              top: 120,
            ),
            child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 15, right: 15, top: 10),
                  child: Text(
                    text.sureDeleteAccount,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Divider(color: Colors.grey, thickness: 0.8),
                Padding(
                  padding: EdgeInsets.only(left: 15, right: 15, top: 10),
                  child: Text(
                    text.deleteAccountLongText,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                //Link text
                Padding(
                  padding: EdgeInsets.only(
                    left: 15,
                    right: 15,
                    top: 10,
                    bottom: 10,
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: text.readPolicy,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      children: [
                        TextSpan(
                          text: text.privacyPolicy,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () async {
                              final url = Uri.parse('https://google.com');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                //Password field
                Padding(
                  padding: EdgeInsets.only(
                    left: 15,
                    right: 15,
                    top: 10,
                    bottom: 10,
                  ),
                  child: TextFormField(
                    decoration: InputDecoration(
                      hintText: text.enterPassword,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(12),
                        ),
                      ),
                      suffixIcon: Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Image.asset(
                                _isPasswordVisible 
                                  ? 'assets/icons/hide.png'
                                  : 'assets/icons/view.png',
                                width: 10,
                                height: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                ),
                //Delete button
                Padding(
                  padding: EdgeInsets.only(
                    left: 15,
                    right: 15,
                    top: 10,
                    bottom: 10,
                  ),
                  child: TextButton(  
                    onPressed: () async {
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
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Center(
                            child: CircularProgressIndicator(),
                          ),
                        );

                        // Re-authenticate the user with their password
                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: password,
                        );
                        await user.reauthenticateWithCredential(credential);

                        // Delete the user account from Firebase Auth
                        await user.delete();

                        // Close loading indicator
                        if (!context.mounted) return;
                        Navigator.of(context).pop();

                        // Navigate to login page and clear navigation stack
                        if (!context.mounted) return;
                        Navigator.of(context).popUntil((route) => route.isFirst);

                        // Show success message
                        if (!context.mounted) return;
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
                    },
                    child: Text(text.deleteMyAccount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
