//Sign up page for the app
//Only email and password sign up is available for now
//Firebase used for authentication

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:foitifinder/pages/sign_up_set_up/phone_verification_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  late TapGestureRecognizer _tapGestureRecognizer;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _fullName;
  late final TextEditingController _username;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
    _fullName = TextEditingController();
    _username = TextEditingController();
    _tapGestureRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        final url = Uri.parse('https://google.com');
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        }
      };
  }

  @override
  void dispose() {
    _tapGestureRecognizer.dispose();
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _username.dispose();
    super.dispose();
  }

  //Function that signs up the user
  void signUp() async {
    UserCredential? userCredential;
    final text = AppLocalizations.of(context)!;
    final email = _email.text;
    final password = _password.text;
    final username = _username.text;
    final fullName = _fullName.text;

    // Client-side validation for password length
    if (password.length < 8) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.smallPassword),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      if (!mounted) return;
      //Manually add hasFinishedSetUp and hasPhotos as false since they are non-nullable inside the db
      //and if a user signs up obviously has no photos or finished setup
      await Provider.of<ProfileProvider>(context, listen: false).registerUser(
        uid: FirebaseAuth.instance.currentUser!.uid,
        username: username,
        fullName: fullName,
        hasFinishedSetUp: false,
        hasPhotos: false,
        bio: null,
        age: null,
        imageUrl: null,
        gender: null,
        minAgeRange: null,
        maxAgeRange: null,
        showOutOfRange: null,
        isBalanced: null,
        interests: null,
      );
      // If successful, navigate to phone verification page
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PhoneVerificationPage()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      //most common FirebaseAuthExceptions
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = text.emailAlreadyInUse;
          break;
        case 'weak-password':
          errorMessage = text.weakPassword;
          break;
        case 'invalid-email':
          errorMessage = text.invalidEmail;
          break;
        case 'operation-not-allowed':
          errorMessage = text.operationNotAllowed;
          break;
        case 'too-many-requests':
          errorMessage = text.tooManyRequests;
          break;
        default:
          errorMessage = text.signUpError;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      //Delete firebase user if db failed
      //If user doesn't get deleted we run in the problem where the user exists in firebase but not in db
      if (userCredential != null) {
        await userCredential.user?.delete();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${text.errorOccured}, $e"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
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
                  //main page container (title, TextFormFields)
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
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            'FoitiFinder',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        //signUp text
                        Text(
                          text.signUpText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        //or text with dividers
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Divider(thickness: 1, color: Colors.grey),
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
                              child: Divider(thickness: 1, color: Colors.grey),
                            ),
                          ],
                        ),
                        //email field
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
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                        ),
                        //password field
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
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
                                            _isPasswordVisible =
                                                !_isPasswordVisible;
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
                            },
                          ),
                        ),
                        //full name field
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextFormField(
                            decoration: InputDecoration(
                              hintText: text.fullName,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                            controller: _fullName,
                          ),
                        ),
                        //username field
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: TextFormField(
                            decoration: InputDecoration(
                              hintText: text.username,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                            ),
                            controller: _username,
                          ),
                        ),
                        //sign up long text
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: Color.fromARGB(255, 94, 94, 94),
                            ),
                            children: [
                              TextSpan(text: text.signUpLongText),
                              TextSpan(
                                text: text.here,
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _tapGestureRecognizer,
                              ),
                            ],
                          ),
                        ),
                        //sign up button
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      signUp();
                                    },
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF8A2BE2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(text.signUp),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  //Already have account log in Row
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
                          Text(text.haveAccount),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.black,
                              textStyle: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: Text(
                              text.login,
                              style: TextStyle(
                                color: const Color.fromARGB(255, 0, 65, 119),
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
  }
}
