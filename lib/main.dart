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
import 'package:foitifinder/wrappers/auth_wrapper.dart';
import 'package:foitifinder/wrappers/internet_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// --- CONTRAST COLORS ---
const Color kBrandPurple = Color(0xFF8A2BE2);
const Color kBrandPurpleDark = Color(0xFF6A1B9A);

// --- LIGHT THEME PALETTE ---
const Color kLightBackground = Color(0xFFF0F2F5);
const Color kLightSurface = Colors.white;
const Color kLightTextPrimary = Color(0xFF1A1B1E); 
const Color kLightTextSecondary = Color(0xFF65676B); 

// --- DARK THEME PALETTE ---
const Color kDarkBackground = Color(0xFF111418);
const Color kDarkSurface = Color(0xFF1F2228); 
const Color kDarkTextPrimary = Color(0xFFE4E6EB); 
const Color kDarkTextSecondary = Color(0xFFB0B3B8); 

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
      child: const FoitiFinder()));
}

class FoitiFinder extends StatelessWidget {
  const FoitiFinder({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return MaterialApp(
      title: 'FoitiFinder',
      routes: {
        '/login': (context) => const LoginPage(),
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: kLightBackground,
        
        colorScheme: const ColorScheme.light(
          primary: kBrandPurple,
          surface: kLightSurface,
          onSurface: Colors.black,
          outline: Colors.grey,
        ),

        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains( WidgetState.selected)) return Colors.white;
            return Colors.grey[600];
          }),
          
          trackColor:  WidgetStateProperty.resolveWith((states) {
            if (states.contains( WidgetState.selected)) return kBrandPurple;
            return Colors.grey[400];
          }),
          
          trackOutlineColor:  WidgetStateProperty.all(Colors.transparent),
        ),

        sliderTheme: SliderThemeData(
          activeTrackColor: kBrandPurple,
          inactiveTrackColor: Colors.grey[300],
          thumbColor: Colors.white,
          overlayColor: kBrandPurple.withValues(alpha: 0.1),
          valueIndicatorColor: kBrandPurple,
        ),

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kLightSurface,
          elevation: 0,
          indicatorColor: Colors.transparent,
          indicatorShape: const CircleBorder(),          
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: kBrandPurple, size: 30);
            }
            return const IconThemeData(color: Colors.grey, size: 28);
          }),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
        
        appBarTheme: const AppBarTheme(
          backgroundColor: kLightSurface,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.black, 
        ),

        floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.grey[500], 
        foregroundColor: Colors.white, 
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),

        searchBarTheme: SearchBarThemeData(
          backgroundColor: WidgetStateProperty.all(Colors.grey[500]),
          surfaceTintColor:  WidgetStateProperty.all(Colors.transparent),
          shadowColor:  WidgetStateProperty.all(Colors.black),
          elevation: WidgetStateProperty.all(0)
        ),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kDarkBackground,

        colorScheme: const ColorScheme.dark(
          primary: kBrandPurple,
          surface: kDarkSurface,
          onSurface: Colors.white,
          surfaceTint: Colors.transparent,
        ),

        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white; // Crisp white contrast
            return Colors.grey[400];
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return kBrandPurple.withValues(alpha: 0.5);
            }
            return Colors.grey[800];
          }),
          
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),

        sliderTheme: SliderThemeData(
          activeTrackColor: kBrandPurple,
          inactiveTrackColor: Colors.grey[800],
          thumbColor: Colors.white,
          overlayColor: kBrandPurple.withValues(alpha: 0.2),
        ),

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kDarkSurface,
          
          elevation: 0,
          indicatorColor: Colors.transparent, 
          indicatorShape: const CircleBorder(),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: kBrandPurple, size: 30);
            }
            return const IconThemeData(color: Colors.grey, size: 28);
          }),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kDarkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBrandPurple, width: 2),
          ),
        ),
        
        appBarTheme: const AppBarTheme(
          backgroundColor: kDarkBackground,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.white,
        ),

        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.grey[800], 
          foregroundColor: Colors.white, 
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),

        searchBarTheme: SearchBarThemeData(
          backgroundColor: WidgetStateProperty.all(Colors.grey[800]),
          surfaceTintColor:  WidgetStateProperty.all(Colors.transparent),
          shadowColor:  WidgetStateProperty.all(Colors.black),
          elevation: WidgetStateProperty.all(0),
        ),
      ),
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
      home: InternetWrapper(  
        child: const AuthWrapper(),
      ),
    );
  }
}


