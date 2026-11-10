//That the app still animates on one scale.
//
//WHY THIS IS A TEST AND NOT A STYLE NOTE. The app had drifted to 19 distinct
//durations and 7 curves, and the reason it drifted is that no single one of
//them was wrong. A page needing a transition picked a plausible number, the
//number was fine on that page, and nothing anywhere compared it to its
//neighbours. The symptom only shows up in use - two things moving beside each
//other at slightly different speeds read as something broken rather than as
//two decisions - and by then there is no way to tell which of the 19 was the
//intruder.
//
//A SOURCE SCAN, like the policy URL one, because what matters is the constant
//written at the call site. Every duration here produces a working animation;
//that is exactly the problem.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/theme/app_colors.dart';

void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  String name(File file) => file.path.split(Platform.pathSeparator).last;

  group('the motion scale is the only scale', () {
    test('no screen writes its own duration', () {
      //THE VALUES THE SCALE REPLACED. A raw Duration outside this set is not
      //flagged: the flight in profile_detail_page measures its own from how
      //far the photo travels, the shimmer's 1600ms is a loop period, and
      //match_page's 450ms is a delay before buttons arm. None of those is a
      //transition on the scale, and each says so where it is written.
      const replaced = [90, 150, 160, 180, 200, 220, 240, 260, 280, 300, 320];

      final offenders = <String>[];
      for (final file in sources) {
        //where the scale itself is defined
        if (name(file) == 'app_colors.dart') continue;
        final source = file.readAsStringSync();
        for (final ms in replaced) {
          if (source.contains('Duration(milliseconds: $ms)')) {
            offenders.add('${name(file)} -> ${ms}ms');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'use AppMotion.press/fast/base/slow instead, or write down '
              'why this one is not on the scale');
    });

    test('no screen writes its own curve', () {
      //fastOutSlowIn is deliberately absent: it accelerates out and
      //decelerates in, which is what a photo covering a measured distance
      //wants and what the scale's decelerate-only curves cannot express.
      const replaced = [
        'Curves.easeOutCubic',
        'Curves.easeOutBack',
        'Curves.easeInOutCubic',
        'Curves.easeInOut',
        'Curves.easeOut',
        'Curves.easeIn',
      ];

      final offenders = <String>[];
      for (final file in sources) {
        if (name(file) == 'app_colors.dart') continue;
        //the hero flight's fade is timed against the flight, not the scale
        if (name(file) == 'profile_detail_page.dart') continue;
        final source = file.readAsStringSync();
        for (final curve in replaced) {
          if (source.contains(curve)) offenders.add('${name(file)} -> $curve');
        }
      }

      expect(offenders, isEmpty,
          reason: 'use AppMotion.standard/emphasized/exit instead');
    });

    test('the scale stays small enough to be a scale', () {
      //FOUR AND THREE. The point is not these exact numbers, it is that
      //adding a fifth duration has to be a decision somebody makes on purpose
      //rather than a number that appears because a page needed one.
      expect(
        {AppMotion.press, AppMotion.fast, AppMotion.base, AppMotion.slow},
        hasLength(4),
        reason: 'two steps of the scale have collapsed onto the same value',
      );
      expect(
        {AppMotion.standard, AppMotion.emphasized, AppMotion.exit},
        hasLength(3),
      );
    });

    test('the steps are in order and none of them is imperceptible', () {
      //UNDER ABOUT 60ms a transition is not seen as movement, it is seen as a
      //cut. A scale step that short would be a duration that does nothing.
      final steps = [
        AppMotion.press,
        AppMotion.fast,
        AppMotion.base,
        AppMotion.slow,
      ];

      expect(steps.first.inMilliseconds, greaterThanOrEqualTo(60));
      for (var i = 1; i < steps.length; i++) {
        expect(
          steps[i].inMilliseconds,
          greaterThan(steps[i - 1].inMilliseconds),
          reason: 'step $i is not longer than the one before it',
        );
      }
      //and nothing on the scale should outlast a page transition
      expect(steps.last.inMilliseconds, lessThanOrEqualTo(400));
    });
  });

  group('a tab change is not a journey', () {
    test('nothing slides the main PageView between tabs', () {
      //WHY A SOURCE SCAN AND NOT A PUMP. MainScreen reaches for FirebaseAuth,
      //FirebaseMessaging and Firestore in initState, so it cannot be mounted
      //in a test - the same limit push_tap_test records about
      //MatchesPageState.openMatch. The decision is still worth guarding,
      //because restoring the slide is a one-word edit and what it breaks is a
      //feel rather than a behaviour, which no assertion would catch.
      //
      //TWO THINGS WERE WRONG WITH ANIMATING. A tap on Profile from Home drew
      //the Matches page across the screen on its way past, and a fixed
      //duration over a variable distance made the two-tab jump the fastest
      //and most aggressive one. The slide belongs to the swipe, where the
      //page is following a finger.
      final source = File('lib/main_screen.dart').readAsStringSync();

      expect(source.contains('animateToPage'), isFalse,
          reason: 'a nav tap jumps; only a swipe slides - see _onItemTapped');
      expect(source.contains('jumpToPage'), isTrue,
          reason: 'the tab change has to move the PageView somehow');
    });

    test('the page view still slides under a finger', () {
      //THE OTHER HALF OF THE SAME DECISION. Jumping on a tap is only right
      //while dragging still slides, so the PageView must keep real scroll
      //physics - swapping in NeverScrollableScrollPhysics unconditionally
      //would make both gestures instant and lose the one that should move.
      final source = File('lib/main_screen.dart').readAsStringSync();

      expect(source.contains('ClampingScrollPhysics'), isTrue,
          reason: 'swiping between tabs should still follow the finger');
    });
  });

  group('one app bar', () {
    test('only PageAppBar builds an AppBar', () {
      //THE EXCEPTIONS, each for a reason that is not "this page is different".
      //edit_profile_page's title is a tab control rather than a line of text,
      //so it cannot pass a String; the two photo pages put their own controls
      //on top of a photograph instead of wearing a bar at all.
      const allowed = {
        'polish.dart', //PageAppBar and GlassAppBar live here
        'edit_profile_page.dart',
        'profile_detail_page.dart',
        'photo_detail_page.dart',
      };

      final offenders = <String>[];
      for (final file in sources) {
        if (allowed.contains(name(file))) continue;
        final source = file.readAsStringSync();
        //PageAppBar( and GlassAppBar( both end in "AppBar(", so match the
        //bare constructor only
        final bare = RegExp(r'(?<![A-Za-z])AppBar\(');
        if (bare.hasMatch(source)) offenders.add(name(file));
      }

      expect(offenders, isEmpty,
          reason: 'build the bar with PageAppBar so every page shares one');
    });
  });
}
