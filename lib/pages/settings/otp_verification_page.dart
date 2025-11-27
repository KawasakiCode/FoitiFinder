import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/l10n/app_localizations.dart';

class OtpVerificationPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpVerificationPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPage();
}

class _OtpVerificationPage extends State<OtpVerificationPage> {
  AppLocalizations get  text => AppLocalizations.of(context)!;
  final List<TextEditingController> controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (var c in controllers) {
      c.dispose();
    }
    for (var f in focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

//when a number is inserted into the controllers
  void _onDigitEntered(int index, String value) {
    if (value.length == 1 && index < 5) {
      FocusScope.of(context).requestFocus(focusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(focusNodes[index - 1]);
    }
  }

//build the 6 controllers
  Widget _buildBox(int index) {
    return SizedBox(
      width: 45,
      child: TextFormField(
        controller: controllers[index],
        focusNode: focusNodes[index],
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          counterText: "",
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => _onDigitEntered(index, value),
      ),
    );
  }

//after pressing verify
  Future<void> _submitOtp() async {
    final code = controllers.map((c) => c.text).join();
    //if code less try again
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the full 6-digit code'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    //get users phone number
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: widget.verificationId,
      smsCode: code,
    );


    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      //should never happen
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Internal Error'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      //link phone number to user
      await currentUser.linkWithCredential(credential);
      if(!mounted)return;
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      settingsProvider.verifyPhone();
      if(!context.mounted)return;
      //return to phoneNumberPage and sent success true
      Navigator.pop(context);

    } on FirebaseAuthException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid code or an error occured. Please try again'),
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
      body: Column(
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) => _buildBox(index)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: TextButton(
              onPressed: _submitOtp,
              child: Text(
                text.verify,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
