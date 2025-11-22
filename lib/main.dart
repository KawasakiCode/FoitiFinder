import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/auth_pages/login.dart';
import 'pages/auth_pages/verify_email.dart';
import 'pages/main_pages/home_page.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase asynchronously without blocking UI
  final firebaseInitialized = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(  
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PushNotificationsProvider())
      ],
      child: MyApp(firebaseInitialized: firebaseInitialized)));
}

class MyApp extends StatelessWidget {
  final Future<FirebaseApp> firebaseInitialized;
  
  const MyApp({super.key, required this.firebaseInitialized});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'My app',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color.fromARGB(255, 88, 88, 88),
        ),
      ),
      themeMode: theme.themeMode,
      home: FutureBuilder(
        future: firebaseInitialized,
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
                      return MyHomePage(); // Now returns the home page with swipe cards
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


