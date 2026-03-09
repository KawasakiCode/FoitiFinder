//Same page as otp page in settings 

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/providers/settings_providers.dart';
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
  bool _isLoading = false;
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
      setState(() {
        _isLoading = false;
      },);
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
      verificationId: widget.verificationId,
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
      },);
      //link phone number to user
      await currentUser.linkWithCredential(credential);
      if(!mounted)return;
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      settingsProvider.verifyPhone();
      if(!context.mounted)return;
      //return to phoneNumberPage and sent success true
      setState(() {
        _isLoading = false;
      },);
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;

      String errorMessage;
      switch (e.code) {
        case 'credential-already-in-use':
          // You will need to add this new string to your localization file
          errorMessage = text.phoneAlreadyInUse; 
          break;
        case 'invalid-verification-code':
          errorMessage = text.invalidOtpCode;
          break;
        case 'network-request-failed':
          errorMessage = text.lostInternet;
          break;
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
      ),
    );
  }
}