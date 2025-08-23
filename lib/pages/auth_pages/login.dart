import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../firebase_options.dart';
import 'signup.dart';
import '../home_page.dart';

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
    //same as signup page
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
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
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
                                'My App',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextFormField(
                              decoration: const InputDecoration(
                                hintText: 'Email',
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
                              //Stateful builder forces only the textformfield to rebuild when you press the eye button instead
                              //of the whole page. Only use it for small widgets and parts of the ui
                              child: StatefulBuilder(
                                builder: (context, setState) {
                                  return TextFormField(
                                    decoration: InputDecoration(
                                      hintText: 'Password',
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
                                      
                                      if(!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Account deleted. Please sign up again and verify your email.'),
                                          backgroundColor: Colors.orange,
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                      return;
                                    }                                    
                                    // Clear navigation stack and navigate to home page
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(builder: (context) => MyHomePage()),
                                      (route) => false, // This removes all previous routes
                                    );
                                    
                                  } on FirebaseAuthException catch (e) {
                                    String errorMessage;
                                    
                                    switch (e.code) {
                                      case 'invalid-credential':
                                        errorMessage = 'Invalid email or password. Please check your credentials and try again.';
                                        break;
                                      case 'invalid-email':
                                        errorMessage = 'Please enter a valid email address.';
                                        break;
                                      case 'user-disabled':
                                        errorMessage = 'This account has been disabled.';
                                        break;
                                      case 'too-many-requests':
                                        errorMessage = 'Too many failed attempts. Please try again later.';
                                        break;
                                      default:
                                        errorMessage = 'An error occurred. Please try again.';
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
                                        content: Text('An unexpected error occurred. Please try again.'),
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
                                child: Text('Login'),
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
                                    'OR',
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
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.only(bottom: 0, top: 10),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/icons/facebookicon.png',
                                        width: 25,
                                        height: 25,
                                      ),
                                      Text(
                                        '  Log in with Facebook',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.center,
                                  child: TextButton(
                                    onPressed: () async{
                                      try {
                                        await FirebaseAuth.instance.sendPasswordResetEmail(
                                          email: _email.text,
                                        );
                                        if(!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Password reset email sent. Please check your email.'),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      } catch (e) {
                                        if(!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(  
                                          SnackBar(  
                                            content: Text('An error occured. Please try again later.'),
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
                                    child: Text('Forgot password?'),
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
                              Text("Don't have an account?"),
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
                                  'Sign up',
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
