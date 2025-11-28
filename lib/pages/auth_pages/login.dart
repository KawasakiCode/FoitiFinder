import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/firebase_options.dart';
import 'package:foitifinder/pages/auth_pages/signup.dart';
import 'package:foitifinder/pages/main_pages/home_page.dart';
import 'package:foitifinder/l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    return FutureBuilder(
      future: Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
      builder: (context, asyncSnapshot) {
        switch (asyncSnapshot.connectionState) {
          case ConnectionState.done:
            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.only(
                              bottom: 10,
                              top: 20,
                              left: 15,
                              right: 15,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey, width: 1),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 25),
                                  child: Text(
                                    'FoitiFinder',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextFormField(
                                  decoration: InputDecoration(
                                    hintText: text.email,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(12),
                                      ),
                                    ),
                                  ),
                                  controller: _email,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                                  child: StatefulBuilder(
                                    builder: (context, setState) {
                                      return TextFormField(
                                        decoration: InputDecoration(
                                          hintText: text.password,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(12),
                                            ),
                                          ),
                                          suffixIcon: Padding(
                                            padding: EdgeInsets.only(right: 8.0),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(20),
                                                onTap: () {
                                                  setState(() {
                                                    _isPasswordVisible = !_isPasswordVisible;
                                                  });
                                                },
                                                child: Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Image.asset(
                                                    _isPasswordVisible 
                                                      ? 'assets/icons/hide.png'
                                                      : 'assets/icons/view.png',
                                                    width: 10,
                                                    height: 10,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        controller: _password,
                                        obscureText: !_isPasswordVisible,
                                        autocorrect: false,
                                        enableSuggestions: false,
                                      );
                                    }
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    onPressed: () async {
                                      final email = _email.text;
                                      final password = _password.text;

                                      try {
                                        final userCredential = await FirebaseAuth.instance
                                        .signInWithEmailAndPassword(
                                          email: email,
                                          password: password,
                                        );
                                        
                                        // Check if email is verified
                                        if (userCredential.user != null && !userCredential.user!.emailVerified) {
                                          // Delete the unverified account
                                          await userCredential.user!.delete();
                                          
                                          if(!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(text.accountDeleted),
                                              backgroundColor: Colors.orange,
                                              duration: Duration(seconds: 4),
                                            ),
                                          );
                                          return;
                                        }                                    
                                        // Clear navigation stack and navigate to home page
                                        if(!context.mounted) return;
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(builder: (context) => MyHomePage()),
                                          (route) => false, // This removes all previous routes
                                        );
                                        
                                      } on FirebaseAuthException catch (e) {
                                        String errorMessage;
                                        
                                        switch (e.code) {
                                          case 'invalid-credential':
                                            errorMessage = text.invalidCredentials;
                                            break;
                                          case 'invalid-email':
                                            errorMessage = text.invalidEmail;
                                            break;
                                          case 'user-disabled':
                                            errorMessage = text.disabledAccount;
                                            break;
                                          case 'too-many-requests':
                                            errorMessage = text.tooManyRequests;
                                            break;
                                          default:
                                            errorMessage = text.errorOccured;
                                        }
                                        
                                        // Show error message to user
                                        if(!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(errorMessage),
                                            backgroundColor: Colors.red,
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      } catch (e) {
                                        // Handle other types of errors
                                        if(!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(text.unexpectedError),
                                            backgroundColor: Colors.red,
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
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
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(text.login),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        thickness: 1,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        13,
                                        10,
                                        13,
                                        10,
                                      ),
                                      child: Text(
                                        text.or,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        thickness: 1,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Align(
                                      alignment: Alignment.center,
                                      child: TextButton(
                                        onPressed: () async{
                                          try {
                                            await FirebaseAuth.instance.sendPasswordResetEmail(
                                              email: _email.text,
                                            );
                                            if(!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(text.passwordResetEmail),
                                                backgroundColor: Colors.green,
                                                duration: Duration(seconds: 3),
                                              ),
                                            );
                                          } catch (e) {
                                            if(!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(  
                                              SnackBar(  
                                                content: Text(text.errorOccured),
                                                backgroundColor: Colors.red,
                                                duration: Duration(seconds: 3),
                                              ),
                                            );
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.only(bottom: 5, top: 0),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor: Colors.black,
                                          textStyle: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        child: Text(text.forgotPassword),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.only(top: 7, bottom: 7),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey, width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(text.noAccount),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SignUpPage(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      textStyle: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    child: Text(
                                      text.signUp,
                                      style: TextStyle(
                                        color: const Color.fromARGB(
                                          255,
                                          0,
                                          65,
                                          119,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
          default: 
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
        }
      },
    );
  }
}
