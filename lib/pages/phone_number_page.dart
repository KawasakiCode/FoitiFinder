import 'package:flutter/material.dart';

class PhoneNumberPage extends StatefulWidget {
  const PhoneNumberPage({super.key});

  @override
  State<PhoneNumberPage> createState() => _PhoneNumberPageState();
}

class _PhoneNumberPageState extends State<PhoneNumberPage> {
  final TextEditingController _phoneNumberController = TextEditingController();

  void _validateAndVerifyNumber() {
    final input  = _phoneNumberController.text.trim();

    //Check for correct format
    final phoneRegex = RegExp(r'^69\d{8}$');
    if (!phoneRegex.hasMatch(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number 69xxxxxxxx'), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
      );
      return;
    }

    final phoneNumber = '+30$input';
    print(phoneNumber);

  }

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
                        border: InputBorder
                            .none,
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
            Text(
              'Unverified Phone Number',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            Center(
              child: TextButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _validateAndVerifyNumber();
                },
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

