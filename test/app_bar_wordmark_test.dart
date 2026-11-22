//The three main tabs wear the logo rather than the app's name in Inter.
//
//WHY THIS IS WORTH A TEST. Every failure mode here is quiet:
//
//  - an Image.asset path is a STRING. Rename or move the file and nothing
//    fails to compile; the app bar draws a grey broken-image box instead, and
//    only on the three pages that use it.
//  - the same is true of the pubspec entry. The file can be on disk, correct,
//    and simply not bundled - which looks identical at runtime.
//  - there are two files because the ink is near-black in one and near-white
//    in the other. Lose the brightness branch and the logo is invisible in
//    one theme rather than wrong in both, so testing in one theme proves
//    nothing.
//  - the height is tuned to the ink of the text it replaced, not to the font
//    size. "Tidying" it to 20 to match appBarTheme is a plausible edit that
//    silently shrinks the logo.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/providers/notifications_provider.dart';
import 'package:foitifinder/widgets/main_app_bar.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:provider/provider.dart';

const String _lightAsset = 'assets/brand/wordmark_on_light.png';
const String _darkAsset = 'assets/brand/wordmark_on_dark.png';
const String _appName = 'FoitiFinder';

void main() {
  Future<void> pumpBar(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<NotificationsProvider>(
        create: (_) => NotificationsProvider(),
        child: MaterialApp(
          //the bell beside the logo reads AppLocalizations.of(context)! for
          //its tooltip, so the bar cannot be built without these
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(brightness: brightness),
          home: const Scaffold(
            appBar: MainAppBar(title: _appName),
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  String assetOf(WidgetTester tester) =>
      (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

  testWidgets('the main tabs show the logo, not the name as text',
      (tester) async {
    await pumpBar(tester, Brightness.light);

    expect(find.byType(Image), findsOneWidget);
    //the bell is an Icon, so the only Image in this bar is the logo
    expect(find.text(_appName), findsNothing,
        reason: 'the app bar is still drawing the name as text');
  });

  testWidgets('it still announces the name', (tester) async {
    await pumpBar(tester, Brightness.light);
    //A PICTURE OF A WORD IS NOT A WORD. Without this a screen reader reads
    //the three main pages as having no title at all.
    expect(tester.widget<Image>(find.byType(Image)).semanticLabel, _appName);
  });

  group('it follows the theme', () {
    testWidgets('light', (tester) async {
      await pumpBar(tester, Brightness.light);
      expect(assetOf(tester), _lightAsset);
    });

    testWidgets('dark', (tester) async {
      await pumpBar(tester, Brightness.dark);
      expect(assetOf(tester), _darkAsset);
    });

    testWidgets('and the two themes do not share one file', (tester) async {
      //the bug this catches is a dropped brightness branch, which looks
      //perfectly fine in whichever theme you happened to open
      expect(_lightAsset, isNot(_darkAsset));
    });
  });

  testWidgets('it is sized to the ink it replaced, not to the font size',
      (tester) async {
    await pumpBar(tester, Brightness.light);
    final Size size = tester.getSize(find.byType(Image));

    //THE FILE IS MOSTLY PADDING - 18% above and below the lettering - so a
    //box matching the 20pt title draws a word that is smaller than it. The
    //height has to exceed the font size for the ink to match it.
    expect(size.height, greaterThan(20.0),
        reason: 'the logo box is no taller than the font size, so the '
            'lettering inside it is smaller than the text it replaced');
    //and it still has to fit the bar it sits in
    expect(size.height, lessThan(kToolbarHeight));
  });

  testWidgets('a page with a real title still gets text', (tester) async {
    //the logo belongs to the brand, not to every heading in the app
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: PageAppBar(title: 'Settings')),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  test('both files are on disk and bundled', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();

    for (final String asset in <String>[_lightAsset, _darkAsset]) {
      expect(File(asset).existsSync(), isTrue,
          reason: '$asset is missing; the app bar would draw a broken image');
      //DECLARED AS A FILE, NOT AS assets/brand/. The folder also holds four
      //1024x1024 icon sources that the Android build takes from outside the
      //APK, and listing the directory ships them to every phone.
      expect(pubspec.contains('- $asset'), isTrue,
          reason: '$asset exists but is not listed in pubspec.yaml, so it is '
              'not in the bundle and Image.asset fails at runtime');
    }
  });
}
