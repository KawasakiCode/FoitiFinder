import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/auth_pages/login.dart';
import 'pages/auth_pages/verify_email.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My app',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FutureBuilder(
        future: Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.done:
              return StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final user = snapshot.data!;
                    if (user.emailVerified) {
                      // User is logged in and email is verified
                      // TODO: Navigate to main app/home page
                      return LoginPage(); // Temporary, replace with home page
                    } else {
                      // User is logged in but email is not verified
                      return VerifyEmail();
                    }
                  } else {
                    // User is not logged in
                    return LoginPage();
                  }
                },
              );
            default:
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
          }
        },
      ),
    );
  }
}


