import 'package:flutter/material.dart';

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({super.key});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPage();
}

class _OtpVerificationPage extends State<OtpVerificationPage> {
  final List<TextEditingController> controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> focusNodes =
      List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (var c in controllers) {c.dispose();}
    for (var f in focusNodes) {f.dispose();}
    super.dispose();
  }

  void _onDigitEntered(int index, String value) {
    if (value.length == 1 && index < 5) {
      FocusScope.of(context).requestFocus(focusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(focusNodes[index - 1]);
    }
  }

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

void _submitOtp() {
    final code = controllers.map((c) => c.text).join();
    if (code.length == 6) {
      print("OTP: $code");
    } else {
      print("Incomplete code");
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(  
      appBar: AppBar(
        title: Text('Verify Phone Number'),
        automaticallyImplyLeading: true,
      ),
      body: Column(  
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, top: 30),
            child: Text('Enter the verification code sent to you phone number',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
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
              child: const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,))
            ),
          )
        ]
      )
    );
  }
}