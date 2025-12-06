import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'pages/auth_pages/login.dart';
import 'pages/auth_pages/verify_email.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// --- CONTRAST COLORS ---
const Color kBrandPurple = Color(0xFF8A2BE2); // Vibrant "Electric" Purple
const Color kBrandPurpleDark = Color(0xFF6A1B9A); // Darker shade for contrast

// --- LIGHT THEME PALETTE ---
const Color kLightBackground = Color(0xFFF0F2F5); // Not pure white (adds depth)
const Color kLightSurface = Colors.white;         // Cards/AppBar
const Color kLightTextPrimary = Color(0xFF1A1B1E); // Almost Black
const Color kLightTextSecondary = Color(0xFF65676B); // Medium Grey

// --- DARK THEME PALETTE (Tinder Style) ---
const Color kDarkBackground = Color(0xFF111418);  // Very dark grey/blue (Not pure black)
const Color kDarkSurface = Color(0xFF1F2228);     // Slightly lighter for cards
const Color kDarkTextPrimary = Color(0xFFE4E6EB); // Off-white
const Color kDarkTextSecondary = Color(0xFFB0B3B8); // Light Grey

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase asynchronously without blocking UI
  final results = await Future.wait([
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
    SharedPreferences.getInstance(),
  ]);
  final prefs = results[1] as SharedPreferences;

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
    final settings = Provider.of<SettingsProvider>(context);
    return MaterialApp(
      title: 'FoitiFinder',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: kLightBackground,
        //for inkwells
        splashFactory: InkRipple.splashFactory,
        splashColor: const Color.fromARGB(59, 70, 70, 70),
        highlightColor: const Color.fromARGB(26, 31, 31, 31),
        //colorScheme
        colorScheme: const ColorScheme.light(  
          primary: kBrandPurple,
          onPrimary: Colors.white,

          secondary: Colors.teal,
          onSecondary: Colors.white,

          surface: kLightSurface,
          onSurface: kLightTextPrimary,

          error: Colors.redAccent,
          onError: Colors.white,
        ),

        //text theme
        textTheme: const TextTheme(  
          bodyMedium: TextStyle(color: kLightTextPrimary), // Default text
          bodySmall: TextStyle(color: kLightTextSecondary), // Subtle text
          titleLarge: TextStyle(color: kLightTextPrimary, fontWeight: FontWeight.bold),
        ),

        //appbar
        appBarTheme: const AppBarTheme(  
          backgroundColor: kLightSurface,
          foregroundColor: kLightTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        //navigation bar
        navigationBarTheme: NavigationBarThemeData(  
          backgroundColor: kLightSurface,
          indicatorColor: kBrandPurple.withValues(alpha: 0.1),
          iconTheme: WidgetStateProperty.all(  
            const IconThemeData(color: kLightTextSecondary)
          )
        )
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kDarkBackground,
        
        //color Scheme
        colorScheme: const ColorScheme.dark(
          primary: kBrandPurple,
          onPrimary: Colors.white,
          
          surface: kDarkSurface,
          onSurface: kDarkTextPrimary,
          
          // Prevent M3 from tinting your grey cards with purple
          surfaceTint: Colors.transparent, 
          
          error: Colors.redAccent,
          onError: Colors.white,
        ),

        //text theme
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: kDarkTextPrimary),
          bodySmall: TextStyle(color: kDarkTextSecondary),
          titleLarge: TextStyle(color: kDarkTextPrimary, fontWeight: FontWeight.bold),
        ),

        //appbar 
        appBarTheme: const AppBarTheme(
          backgroundColor: kDarkBackground, // Or kDarkSurface if you want it distinct
          foregroundColor: kDarkTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        //navigation theme
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kDarkBackground,
          indicatorColor: kBrandPurple.withValues(alpha: 0.2),
          iconTheme: WidgetStateProperty.all(
              const IconThemeData(color: kDarkTextSecondary)),
        ),
        
        //fab theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: kDarkSurface, // Dark Grey button
          foregroundColor: kBrandPurple, // Purple Icon
          elevation: 4,
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
              return const MainScreen();
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


