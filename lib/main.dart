import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'pages/auth_pages/login.dart';
import 'pages/auth_pages/verify_email.dart';
import 'pages/main_pages/home_page.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase asynchronously without blocking UI
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  //Load user preferences and settings
  final prefs = await SharedPreferences.getInstance();
  runApp(
    MultiProvider(  
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
      ],
      child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<SettingsProvider>(context);
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if(snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(  
              body: Center(  
                child: CircularProgressIndicator(),
              )
            );
          }

          if(snapshot.hasData) {
            final user = snapshot.data!;

            if(user.emailVerified)  {
              return const MyHomePage();
            } else {
              return const VerifyEmail();
            }
          } 
          else {
            return const LoginPage();
          }
        },
      ),
    );
  }
}


