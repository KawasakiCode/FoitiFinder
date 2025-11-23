import 'package:flutter/material.dart';
import 'package:foitifinder/pages/settings/otp_verification_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';


class PhoneNumberPage extends StatefulWidget {
  const PhoneNumberPage({super.key});

  @override
  State<PhoneNumberPage> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage> {
  final TextEditingController _phoneNumberController = TextEditingController();
  bool _isValid = false;

  //validate phone number and return it to sent to otp page
  String _validateNumber() {
    final String phoneNumber;
    final input = _phoneNumberController.text.trim();

    //Check for correct format
    final phoneRegex = RegExp(r'^69\d{8}$');
    if (!phoneRegex.hasMatch(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid phone number 69xxxxxxxx'),
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
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (phoneAuthCredential) async {
        Provider.of<SettingsProvider>(context, listen: false).verifyPhone();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone Verified Automatically!'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (!mounted) return;
        Navigator.pop(context); // Just close the page!
      },
      codeSent: (String verificationId, int? resendToken) async {
        // Wait for the user to finish on the OTP page
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationPage(
              verificationId: verificationId,
              phoneNumber: phoneNumber!,
            ),
          ),
        );

        if (!mounted) return;
        final isVerified = Provider.of<SettingsProvider>(context, listen: false).isPhoneVerified;

        if (isVerified) {
          Navigator.pop(context); 
        }
      },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to verify phone number'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code expired'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        },
      );
    }
  }

  //phone_number_page ui
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Phone Number Settings'),
        automaticallyImplyLeading: true,
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phone Number',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Container(
              margin: EdgeInsets.only(top: 10, bottom: 5),
              padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter phone number',
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
            ),
            Center(
              child: TextButton(
                //onpress call validate number and redirect to otp page
                onPressed: _verifyNumber,
                child: Text(
                  'Update My Phone Number',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
