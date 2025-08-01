import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';

class VerifyEmail extends StatefulWidget {
  const VerifyEmail({super.key});

  @override
  State<VerifyEmail> createState() => _VerifyEmailState();
}

class _VerifyEmailState extends State<VerifyEmail> {
  bool _isEmailSent = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Please verify your email address",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text(
              FirebaseAuth.instance.currentUser?.email ?? '',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 20),
            if (_isEmailSent)
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Verification email sent! Please check your inbox.',
                  style: TextStyle(color: Colors.green[800]),
                ),
              ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: _isLoading ? null : () async {
                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                    setState(() {
                      _isEmailSent = true;
                    });
                    
                    if(!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Verification email sent successfully!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  } catch (e) {
                    print(e);
                    if(!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send verification email. Please try again.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  } finally {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color.fromARGB(
                    255,
                    0,
                    65,
                    119,
                  ),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Send Verification Email',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
              ),
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () {
                // Sign out and redirect to login page
                FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (route) => false,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                textStyle: TextStyle(fontSize: 14),
              ),
              child: Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
