import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/widgets/session_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'pages/auth_pages/login.dart';
import 'pages/auth_pages/verify_email.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// --- CONTRAST COLORS ---
const Color kBrandPurple = Color(0xFF8A2BE2); // Vibrant  Purple
const Color kBrandPurpleDark = Color(0xFF6A1B9A); // Darker shade for contrast

// --- LIGHT THEME PALETTE ---
const Color kLightBackground = Color(0xFFF0F2F5); // Not pure white (adds depth)
const Color kLightSurface = Colors.white;         // Cards/AppBar
const Color kLightTextPrimary = Color(0xFF1A1B1E); // Almost Black
const Color kLightTextSecondary = Color(0xFF65676B); // Medium Grey

// --- DARK THEME PALETTE ---
const Color kDarkBackground = Color(0xFF111418);  // Very dark grey/blue
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
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)..init()),
        ChangeNotifierProvider(create: (_) => ProfileProvider(prefs)..init()),
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
      //LIGHT THEME
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: kLightBackground,
        
        // 1. GLOBAL COLORS
        colorScheme: const ColorScheme.light(
          primary: kBrandPurple,
          surface: kLightSurface,
          onSurface: Colors.black,
          outline: Colors.grey, // Fixes default border colors
        ),

        // 2. SWITCHES (Crisp Purple)
        switchTheme: SwitchThemeData(
          // 1. THUMB: White when ON, Dark Grey when OFF (High contrast)
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains( WidgetState.selected)) return Colors.white;
            return Colors.grey[600]; // Darker grey thumb for visibility
          }),
          
          // 2. TRACK: Purple when ON, Mid-Grey when OFF (Fixes "Invisible" issue)
          trackColor:  WidgetStateProperty.resolveWith((states) {
            if (states.contains( WidgetState.selected)) return kBrandPurple;
            return Colors.grey[400]; // Much darker than [200] so you can see it
          }),
          
          // 3. BORDER: Transparent (Cleaner look)
          trackOutlineColor:  WidgetStateProperty.all(Colors.transparent),
        ),

        // 3. SLIDERS (Age Range)
        sliderTheme: SliderThemeData(
          activeTrackColor: kBrandPurple,
          inactiveTrackColor: Colors.grey[300],
          thumbColor: Colors.white,
          overlayColor: kBrandPurple.withValues(alpha: 0.1), // The glow when touching
          valueIndicatorColor: kBrandPurple,
        ),

        // 4. NAVIGATION BAR (Bottom Bar)
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kLightSurface,
          elevation: 0,
          indicatorColor: Colors.transparent,
          indicatorShape: const CircleBorder(),          
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: kBrandPurple, size: 30); // Active Icon
            }
            return const IconThemeData(color: Colors.grey, size: 28); // Inactive Icon
          }),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow, // Tinder style: No text labels
        ),
        
        // 5. APP BAR
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

      // DARK THEME
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kDarkBackground,

        // 1. GLOBAL COLORS
        colorScheme: const ColorScheme.dark(
          primary: kBrandPurple,
          surface: kDarkSurface,
          onSurface: Colors.white,
          surfaceTint: Colors.transparent,
        ),

        // 2. SWITCHES
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white; // Crisp white contrast
            return Colors.grey[400]; // Unselected thumb
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return kBrandPurple.withValues(alpha: 0.5); // <--- TONE DOWN HERE
            }
            return Colors.grey[800]; // Unselected track (Dark Grey)
          }),
          
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),

        // 3. SLIDERS
        sliderTheme: SliderThemeData(
          activeTrackColor: kBrandPurple,
          inactiveTrackColor: Colors.grey[800],
          thumbColor: Colors.white,
          overlayColor: kBrandPurple.withValues(alpha: 0.2),
        ),

        // 4. NAVIGATION BAR
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kDarkSurface, // Matches the "Surface" look
          // OR use Colors.transparent if you rely on the extendBody trick
          
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

        // 5. INPUTS (Profile Page)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kDarkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // Clean look
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBrandPurple, width: 2), // Glows purple when typing
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
            final User user = snapshot.data!;
            if(user.emailVerified)  {
              return SessionGuard(user: user);
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


