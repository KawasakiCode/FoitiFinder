//The logo renders, from the right file, in both themes - and the artwork
//itself still carries the policy site's two colours.
//
//WHY THIS IS WORTH A TEST. The wordmark is the first thing anybody sees and it
//is the one widget in the app that is not allowed to fail quietly. It used to
//be text in a subset font, and this test watched the font family and the two
//TextStyle colours. It is a picture now, which moves every one of those
//failure modes somewhere a widget test cannot see them:
//
//  - the asset path is a STRING. Rename the file, drop the pubspec entry, and
//    Image.asset throws at runtime on the login screen rather than at build.
//  - the two colours are no longer in Dart at all. They are PIXELS, baked in
//    by scripts/make_icon.py, and AppColors still declares them - so the two
//    can now disagree with nothing to notice. That is what the last group
//    here is for: it decodes the shipped PNGs and reads the colours back out.
//  - the brightness branch picks between two files. Lose it and the logo
//    disappears into one of the two scaffolds instead of looking wrong.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/pages/auth_pages/auth_parts.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/brand_wordmark.dart';

const String _lightFile = 'assets/brand/wordmark_on_light.png';
const String _darkFile = 'assets/brand/wordmark_on_dark.png';

void main() {
  Future<Image> pumpBrand(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const Scaffold(body: Center(child: AuthBrand())),
      ),
    );
    return tester.widget<Image>(find.byType(Image));
  }

  String assetOf(Image image) => (image.image as AssetImage).assetName;

  group('the login logo', () {
    testWidgets('draws the light file on a light scaffold', (tester) async {
      expect(assetOf(await pumpBrand(tester, Brightness.light)), _lightFile);
    });

    testWidgets('and the dark file on a dark one', (tester) async {
      expect(assetOf(await pumpBrand(tester, Brightness.dark)), _darkFile);
    });

    testWidgets('and it swaps when dark mode is toggled at runtime',
        (tester) async {
      //NOT THE SAME QUESTION AS THE TWO TESTS ABOVE, which each start a fresh
      //app in one brightness. Dark mode is a switch in settings, so the file
      //has to change under a logo that is already on screen - and that only
      //happens because BrandWordmark reads Theme.of(context), which makes it
      //a dependent of the theme rather than something that sampled it once.
      //
      //WRITING THIS AS TWO pumpWidget CALLS IN ONE TEST DOES NOT WORK, and
      //the way it fails is worth knowing: `const AuthBrand()` is the same
      //instance both times, so Flutter short-circuits on identity and never
      //rebuilds it. The asset comes back unchanged and the test reads as a
      //bug in the app. Driving the theme from a notifier is what makes it a
      //rebuild of the real kind.
      final ValueNotifier<ThemeMode> mode =
          ValueNotifier<ThemeMode>(ThemeMode.light);
      addTearDown(mode.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (_, ThemeMode current, _) => MaterialApp(
            theme: ThemeData(brightness: Brightness.light),
            darkTheme: ThemeData(brightness: Brightness.dark),
            themeMode: current,
            home: const Scaffold(body: Center(child: AuthBrand())),
          ),
        ),
      );
      expect(assetOf(tester.widget<Image>(find.byType(Image))), _lightFile);

      mode.value = ThemeMode.dark;
      await tester.pumpAndSettle();

      expect(assetOf(tester.widget<Image>(find.byType(Image))), _darkFile);
    });

    testWidgets('says its name, since a picture has no words in it',
        (tester) async {
      //NOT LOCALISED AND NOT MEANT TO BE: it is a name. What matters is that a
      //screen reader announces something at all, which an Image without a
      //semanticLabel does not.
      expect((await pumpBrand(tester, Brightness.light)).semanticLabel,
          'FoitiFinder');
    });

    testWidgets('is sized by its ink and not by the old font size',
        (tester) async {
      //36.23, NOT 40. The text this replaced was fontSize 40, and reusing that
      //number for the image height is the mistake this guards: the lettering
      //is 0.7370 of the file's height, so a 40px box draws 29.5px of ink where
      //the text put down 26.7. A 10% larger logo, from a change that looks
      //like a no-op.
      final Image image = await pumpBrand(tester, Brightness.light);
      expect(image.height, closeTo(26.70 / BrandWordmark.inkFraction, 0.05));
      expect(image.height, lessThan(40));
    });

    testWidgets('fits a narrow phone at the largest text size',
        (tester) async {
      //AN IMAGE CANNOT WRAP, so this passes by construction now - and that is
      //exactly why it is worth keeping. The text version needed a FittedBox:
      //"FoitiFinder" at 40pt and a 3x text scale wanted 1322 logical pixels of
      //width, kept wrapping because each half was its own span, and laid out
      //at 320x640 - the whole screen. The logo ate the login form. Anybody
      //putting text back here has to keep this true.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
            child: const Scaffold(body: Center(child: AuthBrand())),
          ),
        ),
      );

      final Size size = tester.getSize(find.byType(AuthBrand));
      expect(size.width, lessThanOrEqualTo(320),
          reason: 'the logo is wider than the phone');
      expect(size.height, lessThan(120),
          reason: 'the logo is ${size.height} tall; it has wrapped or grown');
    });
  });

  //THE ARTWORK AGREES WITH THE PALETTE.
  //
  //AppColors still names these four, and nothing in Dart draws with them any
  //more - the colours that reach the screen are pixels in two PNGs, written by
  //scripts/make_icon.py from its own copy of the same hexes. Two copies of a
  //colour with no test between them is the thing this repo keeps getting
  //bitten by, so this is the test between them: retune the brand violet in
  //Dart without regenerating the images and it fails here, naming both values.
  //
  //FULLY OPAQUE PIXELS ONLY. The lettering is antialiased, so its edges are
  //blends at partial alpha; the interior is exact. Each file comes out with
  //precisely two opaque colours, which are the ink and the accent.
  group('the shipped artwork', () {
    Future<Set<int>> opaqueColoursIn(String path) async {
      final ui.Codec codec =
          await ui.instantiateImageCodec(await File(path).readAsBytes());
      final ui.Image image = (await codec.getNextFrame()).image;
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(data, isNotNull, reason: '$path could not be decoded');

      final Set<int> colours = <int>{};
      for (int i = 0; i + 3 < data!.lengthInBytes; i += 4) {
        if (data.getUint8(i + 3) != 255) continue;
        colours.add((0xFF << 24) |
            (data.getUint8(i) << 16) |
            (data.getUint8(i + 1) << 8) |
            data.getUint8(i + 2));
      }
      return colours;
    }

    test('the light file is the light ink and the light accent', () async {
      expect(
        await opaqueColoursIn(_lightFile),
        <int>{AppColors.wordmarkInk.toARGB32(),
              AppColors.wordmarkAccent.toARGB32()},
      );
    });

    test('the dark file is the dark pair', () async {
      expect(
        await opaqueColoursIn(_darkFile),
        <int>{AppColors.darkWordmarkInk.toARGB32(),
              AppColors.darkWordmarkAccent.toARGB32()},
      );
    });

    test('and the two pairs are actually different', () {
      expect(AppColors.wordmarkInk, isNot(AppColors.darkWordmarkInk));
      expect(AppColors.wordmarkAccent, isNot(AppColors.darkWordmarkAccent));
    });
  });
}
