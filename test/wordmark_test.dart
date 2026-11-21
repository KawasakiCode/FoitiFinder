//The logo renders, in the right face, in the right two colours, in both themes.
//
//WHY THIS IS WORTH A TEST. The wordmark is the first thing anybody sees and
//it is the one widget in the app that is not allowed to fall back gracefully.
//Two of its three failure modes are silent:
//
//  - the font family is a STRING matched against pubspec.yaml. Rename the
//    family, move the asset, or drop the entry, and Flutter does not throw -
//    it quietly draws the logo in Inter and the app still runs.
//  - the colours come from the policy site, and the dark pair exists because
//    the light ink is near-black. Lose the brightness branch and the logo
//    disappears into a dark scaffold rather than looking wrong.
//
//The third - a missing letter in the subset font - is covered next door in
//font_coverage_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/pages/auth_pages/auth_parts.dart';
import 'package:foitifinder/theme/app_colors.dart';

void main() {
  Future<Text> pumpBrand(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const Scaffold(body: Center(child: AuthBrand())),
      ),
    );
    return tester.widget<Text>(find.byType(Text));
  }

  List<TextSpan> halvesOf(Text text) =>
      (text.textSpan! as TextSpan).children!.cast<TextSpan>();

  testWidgets('it spells the name, in two pieces', (tester) async {
    final halves = halvesOf(await pumpBrand(tester, Brightness.light));

    //SPLIT WHERE THE SITE SPLITS IT. site/style.css sets the header as
    //Foiti<span>Finder</span>, and the span is what carries the accent.
    expect(halves.map((s) => s.text).toList(), <String>['Foiti', 'Finder']);

    //and it still reads as one word to anything that concatenates the spans,
    //which is what a screen reader announces
    expect(halves.map((s) => s.text).join(), 'FoitiFinder');
  });

  testWidgets('it is set in the wordmark font', (tester) async {
    final text = await pumpBrand(tester, Brightness.light);
    //on the Text and not on the span - Text.rich puts the widget's style
    //there, and asserting the wrong one passes against a null
    expect(text.style?.fontFamily, 'GlutenWordmark');
  });

  group('the two colours are the policy site\'s', () {
    testWidgets('light', (tester) async {
      final halves = halvesOf(await pumpBrand(tester, Brightness.light));
      expect(halves[0].style?.color, AppColors.wordmarkInk);
      expect(halves[1].style?.color, AppColors.wordmarkAccent);
    });

    testWidgets('dark', (tester) async {
      final halves = halvesOf(await pumpBrand(tester, Brightness.dark));
      expect(halves[0].style?.color, AppColors.darkWordmarkInk);
      expect(halves[1].style?.color, AppColors.darkWordmarkAccent);
    });

    testWidgets('and the two themes do not share one', (tester) async {
      //the bug this catches is a brightness branch that got dropped, which
      //looks fine in whichever theme you happened to be testing in
      expect(AppColors.wordmarkInk, isNot(AppColors.darkWordmarkInk));
      expect(AppColors.wordmarkAccent, isNot(AppColors.darkWordmarkAccent));
    });
  });

  testWidgets('it stays a logo at the largest accessibility text size',
      (tester) async {
    //WHAT GOES WRONG WITHOUT THE FittedBox, measured rather than guessed:
    //"FoitiFinder" at 40pt and a 3x text scale wants 1322 logical pixels of
    //width. Constrained to a 320px phone it wraps, and because each half is
    //its own span it keeps wrapping - the laid-out paragraph comes out
    //320x640, which is the entire screen. The logo eats the login form.
    //
    //NOTHING THROWS WHEN THAT HAPPENS. Text in a Center does not report an
    //overflow the way a Row does, so `takeException()` is null either way and
    //an assertion on it would pass against the broken version. This measures
    //the rendered box instead, which is the thing that actually differs:
    //41.6 high with the FittedBox, 640 without.
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
        reason: 'the logo has wrapped and is ${size.height} tall; '
            'the FittedBox in AuthBrand is what stops that');
  });
}
