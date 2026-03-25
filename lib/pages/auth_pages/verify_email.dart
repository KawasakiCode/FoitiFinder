//Page to sent verification email to the user
//Only accessible through the settings page

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';

class VerifyEmail extends StatefulWidget {
  const VerifyEmail({super.key});

  @override
  State<VerifyEmail> createState() => _VerifyEmailState();
}

class _VerifyEmailState extends State<VerifyEmail> {
  bool _isEmailSent = false;
  bool _isLoading = false;

  Timer? _timer;
  int _countdown = 60;
  bool _canResend = true;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
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
                  text.verifyEmail,
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
              if (_isEmailSent)
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
              //Sent verification email button
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
                            setState(() {
                              _canResend = false;
                            },);
                          } finally {
                            setState(() {
                              //unlock button
                              _isLoading = false;
                            });
                          }
                        },
                  style: TextButton.styleFrom(
                    backgroundColor: Color(0xFF8A2BE2),
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
              //Back button
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  textStyle: TextStyle(fontSize: 14),
                ),
                child: Text(text.backToSettings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
