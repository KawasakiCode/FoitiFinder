//WHICH LANGUAGE THE APP STARTS IN, before anybody has chosen one.
//
//WHY THIS IS A TEST AND NOT JUST A DEFAULT. FoitiFinder is shown to
//recruiters as well as to Greek students, and the two directions are not
//symmetric: a Greek speaker who lands in English changes it once in Settings,
//whereas somebody who lands in Greek has to find that setting while every
//label around it - including the word "Language" - is in Greek. So English is
//the default, and the asymmetry is the reason.
//
//AND THE FALLBACK HAS GONE WRONG HERE BEFORE. _loadDefaults reads
//'language_code', the key changeLanguage() and fetchSettingsFromApi() write;
//it once read 'language', so the lookup ALWAYS missed and every launch
//started in the fallback language and visibly flipped once the API answered.
//A bug like that is invisible while the fallback happens to match the stored
//value, which is exactly why the fallback is pinned here rather than trusted.
//
//THE CASE THAT MATTERS MOST is the unrecognised one. The comparison is
//written against 'el' rather than 'en' so anything else - an empty disk, a
//cleared pref, a language a later build stops shipping, a typo - lands in
//English. Testing only the two known codes would pass with the comparison
//written either way round.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsProvider> providerWithPrefs(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  return SettingsProvider(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the language a first launch starts in', () {
    test('nothing on disk is English', () async {
      //a fresh install, which is the only state a new user is ever in
      final provider = await providerWithPrefs({});
      expect(provider.locale, const Locale('en'));
    });

    test('a saved Greek choice is honoured', () async {
      //the default must not override somebody who has actually chosen
      final provider = await providerWithPrefs({'language_code': 'el'});
      expect(provider.locale, const Locale('el'));
    });

    test('a saved English choice is honoured', () async {
      final provider = await providerWithPrefs({'language_code': 'en'});
      expect(provider.locale, const Locale('en'));
    });
  });

  group('anything unrecognised falls back to English', () {
    //THE REAL POINT OF THE FILE. Each of these is a value that cannot be
    //served, and none of them should leave a non-Greek reader in Greek.
    test('an empty string', () async {
      final provider = await providerWithPrefs({'language_code': ''});
      expect(provider.locale, const Locale('en'));
    });

    test('a language this build does not ship', () async {
      final provider = await providerWithPrefs({'language_code': 'de'});
      expect(provider.locale, const Locale('en'));
    });

    test('the key that used to be read by mistake', () async {
      //'language' is the wrong key - the value is right there and must still
      //be ignored, because writing it is not how a choice is recorded
      final provider = await providerWithPrefs({'language': 'el'});
      expect(provider.locale, const Locale('en'));
    });
  });
}
