//The login page of the app
//Uses firebase with email and password as available sign in methods for now

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/pages/auth_pages/signup.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/auth_pages/auth_parts.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:foitifinder/widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  //variable used to show loading throbber when needed
  bool isLoading = false;
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  //The function that actually logs in the user
  //If login is successful sent user to MainScreen (HomePage)
  //If login fails notify the user
  void _login() async {
    if (!context.mounted) return;
    final email = _email.text.trim();
    final password = _password.text;

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (email.isEmpty && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.emptyFields),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    else if (email.isEmpty && password.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.emptyEmail),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    else if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.emptyPassword),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    // Email validation check
    if (email.length > 254 || !emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.invalidEmail),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });
    try {
      //hard stop so a hung connection can't leave the user waiting forever.
      //sign in is side-effect free, so abandoning it on timeout is safe.
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 30));

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: text.errorOccured,
        );
      }
    } on TimeoutException {
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.requestTimedOut),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      setState(() {
        isLoading = false;
      });
      //Most common FirebaseAuthExceptions
      switch (e.code) {
        case 'invalid-credential':
          errorMessage = text.invalidCredentials;
          break;
        case 'invalid-email':
          errorMessage = text.invalidEmail;
          break;
        case 'user-disabled':
          errorMessage = text.disabledAccount;
          break;
        case 'too-many-requests':
          errorMessage = text.tooManyRequests;
          break;
        case 'network-request-failed':
          errorMessage = text.lostInternet;
          break;
        default:
          errorMessage = text.errorOccured;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.unexpectedError),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        //AbsorbPointer locks the screen while logging in; the loading state
        //lives in the button itself (PrimaryButton), so there is never a second.
        body: AbsorbPointer(
          absorbing: isLoading,
          child: AuthScroll(
            children: [
              const Entrance(child: AuthBrand()),
              const SizedBox(height: 32),
              Entrance(
                order: 1,
                child: SurfaceCard(
                  child: Column(
                    children: [
                      //Email TextFormField
                      TextFormField(
                        decoration: InputDecoration(hintText: text.email),
                        controller: _email,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      //Password TextFormField
                      StatefulBuilder(
                        builder: (context, setState) {
                          return TextFormField(
                            decoration: InputDecoration(
                              hintText: text.password,
                              suffixIcon: PasswordEye(
                                visible: _isPasswordVisible,
                                onTap: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            controller: _password,
                            obscureText: !_isPasswordVisible,
                            autocorrect: false,
                            enableSuggestions: false,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      //Login button
                      PrimaryButton(
                        label: text.login,
                        onPressed: isLoading ? null : _login,
                        isLoading: isLoading,
                      ),
                      //Or text with dividers
                      OrDivider(label: text.or),
                      //Forgot Password button
                      SpringPress(
                        child: TextButton(
                          onPressed: () async {
                            //validate the email before asking Firebase
                            //to send a reset, otherwise an empty/invalid
                            //field just produces a generic error
                            final resetEmail = _email.text.trim();
                            final resetEmailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            );
                            if (resetEmail.isEmpty ||
                                !resetEmailRegex.hasMatch(resetEmail)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(text.invalidEmail),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              return;
                            }
                            setState(() => isLoading = true);
                            try {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(
                                    email: resetEmail,
                                  );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    text.passwordResetEmail,
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text(text.errorOccured),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => isLoading = false);
                              }
                            }
                          },
                          style: TextButton.styleFrom(
                            //onSurface, not a hardcoded colour: black
                            //vanished against the dark background
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurface,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(text.forgotPassword),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              //No account Sign up text
              Entrance(
                order: 2,
                child: AuthSwitchCard(
                  prompt: text.noAccount,
                  action: text.signUp,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignUpPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
