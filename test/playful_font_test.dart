//The font switch in settings changes the face for this run and nothing else.
//
//WHY THIS IS WORTH A TEST. "Session only" is a promise about something that
//does NOT happen, and absences do not announce themselves. Every other switch
//on that settings page writes to SharedPreferences and most also write to
//Postgres, so the natural edit - copying the row above it - makes this one
//persist too, and the app still works perfectly. Nobody notices until a
//preference nobody agreed to store comes back a week later.
//
//The other half is the default. The whole app was set in Gluten for a look,
//and the thing that puts it back is AppTheme.fontFamily, which is one word in
//a file nothing else points at.

import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsProvider> freshProvider() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return SettingsProvider(prefs);
  }

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('the font switch is session only', () {
    test('turning it on writes nothing to disk', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SettingsProvider settings = SettingsProvider(prefs);
      final Set<String> before = prefs.getKeys().toSet();

      settings.togglePlayfulFont(true);

      expect(settings.playfulFont, isTrue, reason: 'it did not take effect');
      expect(prefs.getKeys().toSet(), before,
          reason: 'the switch wrote to SharedPreferences; it is meant to '
              'last for one run and leave nothing behind');
    });

    test('a new launch is back to the default face', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      SettingsProvider(prefs).togglePlayfulFont(true);

      //the same disk, a new provider - which is what reopening the app does
      final SettingsProvider relaunched = await freshProvider();

      expect(relaunched.playfulFont, isFalse);
      expect(relaunched.fontFamily, AppTheme.fontFamily);
    });

    test('it does change the face while it is on', () async {
      final SettingsProvider settings = await freshProvider();

      expect(settings.fontFamily, AppTheme.fontFamily);
      settings.togglePlayfulFont(true);
      expect(settings.fontFamily, AppTheme.playfulFontFamily);
      settings.togglePlayfulFont(false);
      expect(settings.fontFamily, AppTheme.fontFamily);
    });

    test('it tells the app to rebuild', () async {
      final SettingsProvider settings = await freshProvider();
      int notifications = 0;
      settings.addListener(() => notifications++);

      settings.togglePlayfulFont(true);

      //without this the switch moves and the text stays as it was
      expect(notifications, greaterThan(0));
    });
  });

  group('the default face', () {
    test('is Inter, and the other one is the exception', () {
      expect(AppTheme.fontFamily, 'Inter');
      expect(AppTheme.playfulFontFamily, isNot(AppTheme.fontFamily));
    });

    test('a theme built with no argument is the default one', () {
      //THE REVERT, ASSERTED. Building the theme without saying which face is
      //what main.dart used to do and what every test does, so this is the
      //line that fails if the app is left set in the experiment.
      expect(AppTheme.light().appBarTheme.titleTextStyle?.fontFamily,
          AppTheme.fontFamily);
      expect(AppTheme.dark().appBarTheme.titleTextStyle?.fontFamily,
          AppTheme.fontFamily);
    });

    test('and the switch reaches the theme when asked', () {
      final titleFace = AppTheme
          .light(font: AppTheme.playfulFontFamily)
          .appBarTheme
          .titleTextStyle
          ?.fontFamily;

      expect(titleFace, AppTheme.playfulFontFamily);
    });

    test('Greek still has a bundled font behind it', () {
      //GLUTEN HAS NO GREEK - it misses all 63 Greek characters in
      //app_el.arb. Without this fallback the Greek UI is drawn by whatever
      //the phone owns, which is what test/font_coverage_test.dart exists to
      //prevent, and it would only show in the playful face.
      expect(AppTheme.fontFamilyFallback, contains('Inter'));
      expect(
          AppTheme.light(font: AppTheme.playfulFontFamily)
              .appBarTheme
              .titleTextStyle
              ?.fontFamilyFallback,
          contains('Inter'));
    });
  });
}
