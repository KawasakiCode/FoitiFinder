//Sign up page for the app
//Only email and password sign up is available for now
//Firebase used for authentication

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:foitifinder/constants/university_domains.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/auth_pages/auth_parts.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:foitifinder/widgets/primary_button.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  late TapGestureRecognizer _tapGestureRecognizer;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
    _name = TextEditingController();
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
    _name.dispose();
    super.dispose();
  }

  //Function that signs up the user
  void signUp() async {
    UserCredential? userCredential;
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text;

    //Restrictions
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    final nameRegex = RegExp(r"^(?=.*[a-zA-Z])[a-zA-Z\s\-']+$");

    //Empty fields check
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.emptyFields),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    //Username validity check
    if(!nameRegex.hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.nameRestriction),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Email validation check
      if (email.length > 254 || !emailRegex.hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text.invalidEmail),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

    // Client-side validation for password length
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.smallPassword),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check email for correct domain
    String domain = email.split('@').last.toLowerCase().trim();
    bool isAllowed(String domain) => 
      kUniversityDomains.any((d) => domain == d || domain.endsWith('.$d'));

    if (!isAllowed(domain)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(  
          content: Text(text.notSupportedDomain),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        )
      );
      return;
    }

    setState(() {
      _isLoading = true;
    },);
    try {
      userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      //capture the uid now: a concurrent SetupWrapper load could sign us out
      //while registerUser is in flight, making currentUser null later
      final String newUid = userCredential.user!.uid;
      if (!mounted) return;
      //Manually add hasFinishedSetUp and hasPhotos as false since they are non-nullable inside the db
      //and if a user signs up obviously has no photos or finished setup
      await Provider.of<ProfileProvider>(context, listen: false).registerUser(
        uid: newUid,
        name: name,
        hasFinishedSetUp: false,
        hasPhotos: false,
        bio: null,
        birthday: null,
        heightCm: null,
        //NOT prefilled from the university. Where somebody studies says
        //nothing about where they live - a student from Alexandroupoli
        //studying in Komotini would get the wrong answer handed to them and
        //most would never correct it. They pick it themselves in Account
        //Settings, or leave it empty.
        city: null,
        gender: null,
        minAgeRange: null,
        maxAgeRange: null,
        preferredGender: null,
      );

      setState(() {
        _isLoading = false;
      },);
      if (!mounted) return;
      //hand back to the auth router (SetupWrapper): pop the signup page so the
      //wrapper underneath becomes visible; it routes to VerifyEmail because the
      //new account isn't verified yet, then photos -> setup.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      },);
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
        case 'network-request-failed':
          errorMessage = text.lostInternet;
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
      setState(() {
        _isLoading = false;
      },);
      //Delete firebase user if db failed
      //If user doesn't get deleted we run in the problem where the user exists in firebase but not in db
      //The delete itself can throw (e.g. network); swallow that so it doesn't
      //hide the original error from the user.
      if (userCredential != null) {
        try {
          await userCredential.user?.delete();
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.signUpError),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        //AbsorbPointer locks the screen while signing up; the loading state
        //lives in the button itself (PrimaryButton), so there is never a second.
        body: AbsorbPointer(
          absorbing: _isLoading,
          child: AuthScroll(
            children: [
              const Entrance(child: AuthBrand()),
              const SizedBox(height: 32),
              //main page container (title, TextFormFields)
              Entrance(
                order: 1,
                child: SurfaceCard(
                  child: Column(
                    children: [
                      //signUp text
                      Text(
                        text.signUpText,
                        textAlign: TextAlign.center,
                        style: mutedText(context),
                      ),
                      //or text with dividers
                      OrDivider(label: text.or),
                      //email field
                      TextFormField(
                        decoration: InputDecoration(hintText: text.email),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                      const SizedBox(height: 16),
                      //password field
                      StatefulBuilder(
                        builder: (context, setState) {
                          return TextFormField(
                            decoration: InputDecoration(
                              hintText: text.password,
                              suffixIcon: PasswordEye(
                                visible: _isPasswordVisible,
                                onTap: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            controller: _password,
                            obscureText: !_isPasswordVisible,
                            autocorrect: false,
                            enableSuggestions: false,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      //name field - the only one. There is no separate
                      //username: nothing in the app looks anyone up by a
                      //handle, so it was a second thing to invent for no
                      //purpose.
                      TextFormField(
                        decoration: InputDecoration(hintText: text.name),
                        controller: _name,
                      ),
                      const SizedBox(height: 16),
                      //sign up long text
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: mutedInk(context),
                          ),
                          children: [
                            TextSpan(text: text.signUpLongText),
                            TextSpan(
                              text: text.here,
                              style: const TextStyle(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: _tapGestureRecognizer,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      //sign up button
                      PrimaryButton(
                        label: text.signUp,
                        onPressed: _isLoading ? null : signUp,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              //Already have account log in Row
              Entrance(
                order: 2,
                child: AuthSwitchCard(
                  prompt: text.haveAccount,
                  action: text.login,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
