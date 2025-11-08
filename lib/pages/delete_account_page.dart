import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_pages/login.dart';

class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delete Account'),
        automaticallyImplyLeading: true,
      ),
      body: Padding(
        padding: const EdgeInsets.only(
          left: 25,
          right: 25,
          top: 120,
        ),
        child: SizedBox(
          height: 330,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                //header text
                Padding(
                  padding: EdgeInsets.only(left: 15, right: 15, top: 10),
                  child: Text(
                    "Are you sure you want to delete your account?",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Divider(color: Colors.grey, thickness: 0.8),
                //long text
                Padding(
                  padding: EdgeInsets.only(left: 15, right: 15, top: 10),
                  child: Text(
                    '''Your profile will be removed from FoitiFinder and won't be visible to other members. If you change your mind within 10 days, you can sign in to recover your account. After 10 days we will delete your data in accordance with our Privacy Policy and you will no longer be able to recover your profile.''',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                //Link text
                Padding(
                  padding: EdgeInsets.only(
                    left: 15,
                    right: 15,
                    top: 10,
                    bottom: 10,
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: 'Read our ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      children: [
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () async {
                              final url = Uri.parse('https://google.com');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                //Delete button
                Padding(
                  padding: EdgeInsets.only(
                    left: 15,
                    right: 15,
                    top: 10,
                    bottom: 10,
                  ),
                  child: TextButton(  
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser!;

                      try {
                        // Show loading indicator
                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Center(
                            child: CircularProgressIndicator(),
                          ),
                        );

                        // Get user data before deletion (if needed for Firestore deletion or logging)
                        // You can add Firestore deletion here if needed:
                        // await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

                        // Delete the user account from Firebase Auth
                        await user.delete();

                        // Close loading indicator
                        if (!context.mounted) return;
                        Navigator.of(context).pop();

                        // Navigate to login page and clear navigation stack
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => LoginPage()),
                          (route) => false, // This removes all previous routes
                        );

                        // Show success message
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Your account has been successfully deleted.'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      } on FirebaseAuthException catch (e) {
                        // Close loading indicator if still showing
                        if (!context.mounted) return;
                        Navigator.of(context).pop();

                        String errorMessage;
                        switch (e.code) {
                          case 'requires-recent-login':
                            errorMessage = 'For security reasons, please log out and log back in before deleting your account.';
                            break;
                          case 'user-not-found':
                            errorMessage = 'User account not found.';
                            break;
                          default:
                            errorMessage = 'An error occurred while deleting your account: ${e.message}';
                        }

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      } catch (e) {
                        // Close loading indicator if still showing
                        if (!context.mounted) return;
                        Navigator.of(context).pop();

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('An unexpected error occurred: $e'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    child: Text('Delete My Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
