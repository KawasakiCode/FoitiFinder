//This is the page where the user can change their phone number
//after the initial sign up 

import 'package:flutter/material.dart';
import 'package:foitifinder/pages/settings/otp_verification_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/l10n/app_localizations.dart';


class PhoneNumberPage extends StatefulWidget {
  const PhoneNumberPage({super.key});

  @override
  State<PhoneNumberPage> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage> {
  bool _isLoading = false;
  AppLocalizations get  text => AppLocalizations.of(context)!;
  final TextEditingController _phoneNumberController = TextEditingController();
  bool _isValid = false;

  //Validate phone number and return it to sent to otp page
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
    setState(() {
      _isLoading = true;
    },);
    FocusScope.of(context).unfocus();
    String? phoneNumber = _validateNumber();
    //if phone number is valid
    if (_isValid && phoneNumber != "") {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (phoneAuthCredential) async {
        Provider.of<SettingsProvider>(context, listen: false).verifyPhone();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text.snackbarVerified),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isLoading = false;
        },);
        if (!mounted) return;
        Navigator.pop(context);
      },
      codeSent: (String verificationId, int? resendToken) async {
        // Wait for the user to finish on the OTP page
        setState(() {
          _isLoading = false;
        },);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationPage(
              verificationId: verificationId,
              phoneNumber: phoneNumber,
            ),
          ),
        );

        if (!mounted) return;
        final isVerified = Provider.of<SettingsProvider>(context, listen: false).isPhoneVerified;

        if (isVerified) {
          setState(() {
            _isLoading = false;
          },);
          Navigator.pop(context); 
        }
      },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          },);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(text.snackbarVerifyFailed),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          setState(() {
            _isLoading = false;
          },);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(text.snackbarCodeExpired),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        },
      );
    }
  }

  //UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(text.phoneNumberSettings),
        automaticallyImplyLeading: true,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: GestureDetector(
          onTap:() => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.phoneNumber,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
                    //Onpress calls validate number and redirects to otp page
                    onPressed: _verifyNumber,
                    child: Text(
                      text.updatePhoneNumber,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
