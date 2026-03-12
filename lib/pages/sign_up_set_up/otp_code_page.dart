//Same page as otp page in settings

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/widgets/otp_input_widget.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';

class OtpCodePage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpCodePage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpCodePage> createState() => _OtpCodePage();
}

class _OtpCodePage extends State<OtpCodePage> {
  //countdown for otp code expiration
  //variables used for the resend button
  int _countdown = 60;
  bool _canResend = false;
  Timer? _timer;
  late String _currentVerificationId;

  bool _isLoading = false;
  AppLocalizations get text => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startTimer();
  }

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

  Future<void> _resendCode() async {
    if(!_canResend)return;

    setState(() {
      _isLoading = true;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(  
      phoneNumber: widget.phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {

      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text.snackbarVerifyFailed), // You can customize this error
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _isLoading = false;
          _currentVerificationId = verificationId;
        });
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text.newCodeSent),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _currentVerificationId = verificationId;
      }
    );
  }

  //after pressing verify
  Future<void> _submitOtp(String code) async {
    // final code = controllers.map((c) => c.text).join();
    //if code less try again
    if (code.length < 6) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.enterOtpCode),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    //get users phone number
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: _currentVerificationId,
      smsCode: code,
    );

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      //should never happen
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text.errorOccured),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      setState(() {
        _isLoading = true;
      });
      //link phone number to user
      await currentUser.linkWithCredential(credential);
      if (!mounted) return;
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      settingsProvider.verifyPhone();
      if (!context.mounted) return;
      //return to phoneNumberPage and sent success true
      setState(() {
        _isLoading = false;
      });
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;

      String errorMessage;
      switch (e.code) {
        case 'credential-already-in-use':
          errorMessage = text.phoneAlreadyInUse;
          Navigator.pop(context);
          break;
        case 'invalid-verification-code':
          errorMessage = text.invalidOtpCode;
          break;
        case 'network-request-failed':
          errorMessage = text.lostInternet;
          break;
        case 'too-many-requests':
          errorMessage = text.tooManyRequests;
          Navigator.pop(context);
        default:
          errorMessage = text.errorOccured;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Fallback for any non-Firebase errors
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.errorOccured),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  //otp page ui
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(text.verifyPhoneNumber),
        automaticallyImplyLeading: true,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, top: 30),
              child: Text(
                text.enterCode,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 15, bottom: 5),
              child: OtpInputWidget(  
                length: 6,
                onCompleted: (String code) {
                  _submitOtp(code);
                },
                focusedBorderColor: Color(0xFF8A2BE2)
              )
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                onPressed: _canResend ? _resendCode : null,
                child: Text(
                  _canResend 
                      ? text.resendCode
                      : "${text.resendIn} ${_countdown}s", 
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w500,
                    color: _canResend ? null : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
