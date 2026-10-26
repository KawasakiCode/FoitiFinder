//The main frame of the app
//Material app, firebase Auth and shared preferences launch here
//Contains the theme of the app and the locale(language)
//Contains an internet wrapper and the auth wrapper

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/auth_pages/login.dart';
import 'package:foitifinder/providers/notifications_provider.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/swipe_queue.dart';
import 'package:foitifinder/theme/app_theme.dart';
import 'package:foitifinder/wrappers/auth_wrapper.dart';
import 'package:foitifinder/wrappers/internet_wrapper.dart';
import 'package:foitifinder/wrappers/version_gate.dart';
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
  //swipes that could not be delivered live on disk until they can be - see
  //swipe_queue.dart. Set up before any UI, because the deck uses it.
  SwipeQueue.init(prefs);
  //APP CHECK PROVES THE CALLER IS THIS APP, not a script with a stolen key.
  //
  //AndroidProvider.debug sends a debug token that only works for devices
  //registered by hand in the Firebase console - correct while developing,
  //useless in anyone else's hands. Play Integrity is the real one, and it is
  //what a release build has to use, so the provider follows the build rather
  //than being a flag somebody has to remember to flip before shipping.
  //
  //kDebugMode is a compile-time constant, so the release binary contains only
  //the playIntegrity branch.
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => ProfileProvider(prefs)),
        //the bell is in the app bar of every main page, so its list lives
        //above all of them rather than being fetched three times
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
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
        //OUTSIDE InternetWrapper, so the wall REPLACES the app rather
        //than sitting inside something that is still listening for
        //connectivity and showing snackbars over the top of it.
        return VersionGate(
          child: InternetWrapper(
            //The curtain sits ABOVE the whole app and below nothing, so it hides
            //the locale rebuild wherever the user happens to be. IgnorePointer
            //because an Opacity of 0 still hit-tests - without it an invisible
            //sheet would swallow every tap in the app.
            child: Stack(
              children: [
                child!,
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: settings.localeSwitching ? 1 : 0,
                    duration: SettingsProvider.localeFadeDuration,
                    curve: Curves.easeOut,
                    child: ColoredBox(
                      //the app's own background, so it reads as the screen
                      //settling rather than a black flash
                      color: (settings.themeMode == ThemeMode.dark
                              ? AppTheme.dark
                              : AppTheme.light)
                          .scaffoldBackgroundColor,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      home: const AuthWrapper(),
    );
  }
}
