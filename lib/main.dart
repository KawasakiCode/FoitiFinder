//The main frame of the app
//Material app, firebase Auth and shared preferences launch here
//Contains the theme of the app and the locale(language)
//Contains an internet wrapper and the auth wrapper

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:foitifinder/theme/app_colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/auth_pages/login.dart';
import 'package:foitifinder/providers/notifications_provider.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/error_reporting.dart';
import 'package:foitifinder/services/swipe_queue.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
  //EVERYTHING INSIDE THIS IS WATCHED: Firebase failing to start, App Check
  //being rejected, a corrupt SharedPreferences. Those are startup crashes,
  //and they are the ones nobody can report by hand because the app never
  //draws a frame. Without a DSN this just runs the callback.
  await runWithErrorReporting(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _registerFontLicences();
    //THE BUILD NUMBER, so an error can be attributed to a release. Read here
    //rather than inside the reporter because package_info is async and the
    //reporter has to be usable from a synchronous catch block.
    final info = await PackageInfo.fromPlatform();
    Sentry.configureScope(
      (scope) => scope.setTag('build', info.buildNumber),
    );
    await _startApp();
  });
}

//THE OFL REQUIRES THE LICENCE TO SHIP WITH THE FONT, and a .ttf inside an APK
//is a distribution like any other. Flutter collects licences from PACKAGES by
//itself; a font dropped into assets/ is invisible to that, so without this
//nothing on the licence screen the profile page opens would mention Inter at
//all - while the APK carried 874 KB of it.
//
//Clause 2 is the one being satisfied: a redistributed copy "must contain the
//above copyright notice and this license", as "stand-alone text files,
//human-readable headers or in the appropriate machine-readable metadata
//fields". The text file is bundled and handed to the same registry
//showLicensePage reads, which makes it all three.
//
//ONE FAMILY, BECAUSE THERE IS NOW ONLY ONE FONT. This used to register
//Gluten's OFL against 'GlutenWordmark' as well; that font is gone and the
//logo is artwork. If a second face is ever bundled, it needs its own entry -
//Flutter will not find it on its own.
//
//ASYNC AND LAZY: addLicense takes a generator, and nothing reads it until the
//user opens the licence screen, so this costs nothing at startup.
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    final String text =
        await rootBundle.loadString('assets/fonts/OFL-Inter.txt');
    yield LicenseEntryWithLineBreaks(const <String>['Inter'], text);
  });
}

Future<void> _startApp() async {
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
  //AndroidProvider.debug sends a token that only works for devices registered
  //by hand in the Firebase console. Play Integrity is the real one and is what
  //a release build must use, so the provider follows the build rather than
  //being a flag somebody has to remember to flip before shipping. kDebugMode
  //is a compile-time constant, so the release binary contains only the
  //playIntegrity branch.
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
      //visual styling lives in lib/theme/ (tokens + AppTheme)
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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
                    curve: AppMotion.standard,
                    child: ColoredBox(
                      //the app's own background, so it reads as the screen
                      //settling rather than a black flash
                      color: (settings.themeMode == ThemeMode.dark
                              ? AppTheme.dark()
                              : AppTheme.light())
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
