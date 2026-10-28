//The launch gradient exists twice and must stay one colour scheme.
//
//WHY TWICE AT ALL. The native one is compiled Android XML, read by the OS
//before a line of Dart runs; the Dart one covers the moment after Flutter
//starts and before the app knows which screen to show. Neither can read the
//other - the first is gone by the time the second exists - so the values are
//duplicated, and this is what stops them drifting.
//
//AND DRIFT IS WORSE THAN NOT MATCHING AT ALL. Two gradients a shade apart
//read as a flicker partway through launching, which looks like the app
//restarting. One deliberate cut would at least look intentional.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/widgets/launch_screen.dart';

String hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

void main() {
  group('the two gradients agree', () {
    //the v21 copy is the one with every layer; the plain drawable/ one is the
    //pre-21 fallback and carries the same three stops
    final drawable = File(
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ).readAsStringSync();

    test('on the colour it starts from', () {
      expect(drawable, contains('android:startColor="${hex(kLaunchGradientStart)}"'));
    });

    test('on the colour in the middle', () {
      expect(drawable, contains('android:centerColor="${hex(kLaunchGradientMiddle)}"'));
    });

    test('on the colour it ends on', () {
      expect(drawable, contains('android:endColor="${hex(kLaunchGradientEnd)}"'));
    });

    test('and the pre-21 fallback has the same three', () {
      final fallback = File(
        'android/app/src/main/res/drawable/launch_background.xml',
      ).readAsStringSync();
      expect(fallback, contains(hex(kLaunchGradientStart)));
      expect(fallback, contains(hex(kLaunchGradientMiddle)));
      expect(fallback, contains(hex(kLaunchGradientEnd)));
    });
  });

  group('the Android 12+ theme', () {
    final styles = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();

    test('draws the gradient behind the window', () {
      //WITHOUT THIS THE GRADIENT IS NEVER SEEN on a modern phone. LaunchTheme
      //falls back to the parent theme's plain background, so API 31+ goes
      //system splash -> white -> app and the drawable only ever applies to
      //Android 11 and below. It was missing exactly that way once.
      expect(styles, contains(
          '<item name="android:windowBackground">@drawable/launch_background</item>'));
    });

    test('and its solid splash is the gradient middle', () {
      //the OS splash takes a colour and not a drawable, so the best available
      //is the stop that the gradient is already closest to where they meet
      expect(styles, contains(
          '<item name="android:windowSplashScreenBackground">'
          '${hex(kLaunchGradientMiddle)}</item>'));
    });
  });

  testWidgets('it shows a spinner that is visible against it', (tester) async {
    //the theme's accent is this gradient's own middle colour, so a default
    //spinner would be near-invisible in the middle of the screen - which is
    //where it sits
    await tester.pumpWidget(const MaterialApp(home: LaunchScreen()));

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.color, Colors.white);
  });

  testWidgets('and takes something else when given it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LaunchScreen(child: Text('loading'))),
    );
    expect(find.text('loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
