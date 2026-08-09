//The main frame of the app
//Material app, firebase Auth and shared preferences launch here
//Contains the theme of the app and the locale(language)
//Contains an internet wrapper and the auth wrapper

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/auth_pages/login.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/theme/app_theme.dart';
import 'package:foitifinder/wrappers/auth_wrapper.dart';
import 'package:foitifinder/wrappers/internet_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and Shared Preferences together to reduce wait time
  final results = await Future.wait([
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
    SharedPreferences.getInstance(),
  ]);
  final prefs = results[1] as SharedPreferences;
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => ProfileProvider(prefs)),
      ],
      child: const FoitiFinder(),
    ),
  );
}

class FoitiFinder extends StatelessWidget {
  const FoitiFinder({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return MaterialApp(
      title: 'FoitiFinder',
      scaffoldMessengerKey: globalMessengerKey,
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginPage(),
      },
      //All visual styling now lives in lib/theme/ (tokens + AppTheme).
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('el'),
      ],
      //app launch flow is main -> authwrapper -> mainscreen (load from disk) -> load from db if different
      //or main -> authwrapper -> login if no user in firebase cache
      builder: (context, child) {
        return InternetWrapper(child: child!);
      },
      home: const AuthWrapper(),
    );
  }
}
