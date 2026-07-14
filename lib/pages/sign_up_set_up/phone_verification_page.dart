//Same page with settings phone number verification page

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/pages/sign_up_set_up/add_photos.dart';
import 'package:foitifinder/pages/sign_up_set_up/otp_code_page.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';

class PhoneVerificationPage extends StatefulWidget {
  const PhoneVerificationPage({super.key});

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPage();
}

class _PhoneVerificationPage extends State<PhoneVerificationPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;
  final TextEditingController _phoneNumberController = TextEditingController();
  bool _isValid = false;
  bool _isLoading = false;

  //Timer to stop loading when anit spam is enabled by firebase
  Timer? _timeoutTimer;

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  //validate phone number and return it to sent to otp page
  String _validateNumber() {
    final String phoneNumber;
    final input = _phoneNumberController.text.trim();
    final text = AppLocalizations.of(context)!;

    //Check for correct format
    final phoneRegex = RegExp(r'^69\d{8}$');
    if (!phoneRegex.hasMatch(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.snackbarNonValidPhoneNumber),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return "";
    }
    _isValid = true;
    phoneNumber = '+30$input';
    return phoneNumber;
  }

  Future<void> _verifyNumber() async {
    FocusScope.of(context).unfocus();
    String? phoneNumber = _validateNumber();
    //if phone number is valid
    if (_isValid && phoneNumber != "") {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      //Early collision check via the backend (Firebase Admin): tell the user the
      //number is taken NOW, before any SMS / reCAPTCHA / OTP entry. Fails open,
      //so a backend hiccup never blocks signup — the link-time check still guards.
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final inUse =
            await ApiService.isPhoneInUse(phoneNumber, currentUser.uid);
        if (!mounted) return;
        if (inUse) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(text.phoneAlreadyInUse),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      _timeoutTimer?.cancel();
      //60s, not 10s: the reCAPTCHA challenge needs user interaction and easily
      //takes longer than 10s, which was firing this "timed out" error even
      //though the flow then succeeded. verifyPhoneNumber's callbacks handle the
      //real terminal states; this is only a safety net for a true hang.
      _timeoutTimer = Timer(const Duration(seconds: 60), () {
        if (mounted && _isLoading) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(text.requestTimedOut),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
      try {
        //await FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (phoneAuthCredential) async {
            _timeoutTimer?.cancel();
            //Auto-retrieval / instant verification fired. Actually LINK the
            //number to the account — without this the phone is only marked
            //verified locally but never saved on Firebase.
            try {
              await FirebaseAuth.instance.currentUser
                  ?.updatePhoneNumber(phoneAuthCredential);
            } on FirebaseAuthException catch (e) {
              if (mounted) setState(() => _isLoading = false);
              if (!mounted) return;
              final msg = (e.code == 'credential-already-in-use' ||
                      e.code == 'provider-already-linked')
                  ? text.phoneAlreadyInUse
                  : text.errorOccured;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
              return;
            }
            if (!mounted) return;
            Provider.of<SettingsProvider>(context, listen: false).verifyPhone();

            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(text.snackbarVerified),
                backgroundColor: Colors.green,
              ),
            );
            if (!mounted) return;
            //onboarding continues to the photo step, same as the OTP success path
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AddPhotos()),
            );
          },
          codeSent: (String verificationId, int? resendToken) async {
            _timeoutTimer?.cancel();
            // Wait for the user to finish on the OTP page
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtpCodePage(
                  verificationId: verificationId,
                  phoneNumber: phoneNumber,
                ),
              ),
            );

            if (!mounted) return;
            final isVerified = Provider.of<SettingsProvider>(
              context,
              listen: false,
            ).isPhoneVerified;
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            if (isVerified) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AddPhotos()),
              );
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            _timeoutTimer?.cancel();
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            if(!mounted)return;
            String errorMessage;
            switch (e.code) {
              case 'credential-already-in-use':
                errorMessage = text.phoneAlreadyInUse;
                break;
              case 'provider-already-linked':
                errorMessage = text.phoneAlreadyInUse;
                break;
              case 'invalid-verification-code':
                errorMessage = text.invalidOtpCode;
                break;
              case 'network-request-failed':
                errorMessage = text.lostInternet;
                break;
              case 'too-many-requests':
                errorMessage = text.tooManyRequests;
              default:
                errorMessage = text.errorOccured;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          },
          codeAutoRetrievalTimeout: (verificationId) {
            _timeoutTimer?.cancel();
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
      } catch (e) {
        _timeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
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
  }

  //phone_number_page ui
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(text.phoneNumberSettings),
          automaticallyImplyLeading: false,
        ),
        body: LoadingOverlay(
          isLoading: _isLoading,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      text.phoneNumber,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneNumberController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            hintText: text.phoneNumberPlaceholder,
                            hintStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: TextButton(
                      //onpress call validate number and redirect to otp page
                      onPressed: _verifyNumber,
                      child: Text(
                        text.verifyPhoneNumber,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
