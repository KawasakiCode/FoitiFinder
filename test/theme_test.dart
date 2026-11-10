//The surface-container ramp must stay NEUTRAL.
//
//ColorScheme.fromSeed builds all five surfaceContainer roles by tinting the
//seed, and our seed is violet - so left alone they come out lavender. In dark
//mode that is a visible blue against the near-black canvas, and it showed up
//as the cards flashing blue for a frame whenever a dialog's barrier faded in
//over them (only ONE of the five roles was pinned at the time).
//
//Different widgets reach for different roles - AlertDialog uses
//surfaceContainerHigh, BottomSheet surfaceContainerLow - so pinning some and
//not others means the tint reappears the moment a new widget is used. This
//test fails if any of them drifts back toward the seed.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/theme/app_theme.dart';

//how far a colour sits from neutral grey: 0 means R == G == B
int _chroma(Color c) {
  final channels = [
    (c.r * 255).round(),
    (c.g * 255).round(),
    (c.b * 255).round(),
  ];
  return channels.reduce((a, b) => a > b ? a : b) -
      channels.reduce((a, b) => a < b ? a : b);
}

//the grey level of a neutral colour, 0-255. Only meaningful where R == G == B,
//which the chroma tests above already require of the ramp.
int _level(Color c) => (c.r * 255).round();

//WCAG relative luminance, which is not the same as the grey level: sRGB is
//gamma encoded, so the gap between two dark colours is a much larger ratio
//than the gap between two light ones.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  //ZERO. Any bias at all is invisible at rest and clearly visible while a
  //surface is being dimmed - see the note on the dark neutrals in
  //app_colors.dart. This started at 4, which is exactly the bias that made
  //cards flash blue behind a dialog barrier.
  const int maxChroma = 0;

  for (final entry in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
    group('${entry.key} theme', () {
      final scheme = entry.value.colorScheme;

      final roles = <String, Color>{
        'surfaceContainerLowest': scheme.surfaceContainerLowest,
        'surfaceContainerLow': scheme.surfaceContainerLow,
        'surfaceContainer': scheme.surfaceContainer,
        'surfaceContainerHigh': scheme.surfaceContainerHigh,
        'surfaceContainerHighest': scheme.surfaceContainerHighest,
      };

      roles.forEach((name, colour) {
        test('$name is neutral, not seed-tinted', () {
          expect(
            _chroma(colour),
            lessThanOrEqualTo(maxChroma),
            reason:
                '$name is tinted (chroma ${_chroma(colour)}). Pin it in '
                'AppTheme._build alongside the other container roles.',
          );
        });
      });

      test('surface tint overlay is off', () {
        //M3 tints elevated Material with this; we want flat surfaces
        expect(scheme.surfaceTint.a, 0);
      });
    });
  }

  //WHY THE LEVELS ARE TESTED AND NOT JUST THE HUE. The ramp above was neutral,
  //pinned and tinted-proof, and dark mode still read as one flat sheet with
  //writing on it - because every step of it lived between 10 and 40 of 255.
  //Neutrality was never the problem; the problem was that the whole scale was
  //crushed against black, where a display reflects more light than it emits
  //and the steps disappear into the reflection. A chroma test cannot see that.
  group('the dark ramp', () {
    //ABOVE THE REFLECTION FLOOR. #121212 is where Material's dark guidance,
    //Spotify, YouTube and Netflix all sit, give or take a couple of units.
    //Pure black is the value you get for not choosing one.
    test('does not start at black', () {
      expect(_level(AppColors.darkBackground), greaterThanOrEqualTo(0x12));
    });

    test('climbs, and never sideways', () {
      final ramp = <String, Color>{
        'darkBackground': AppColors.darkBackground,
        'darkSurfaceLow': AppColors.darkSurfaceLow,
        'darkSurface': AppColors.darkSurface,
        'darkSurfaceHigh': AppColors.darkSurfaceHigh,
        'darkSurfaceVariant': AppColors.darkSurfaceVariant,
        'darkElevated': AppColors.darkElevated,
        'darkBorder': AppColors.darkBorder,
      };

      final names = ramp.keys.toList();
      for (var i = 1; i < names.length; i++) {
        expect(
          _level(ramp[names[i]]!),
          greaterThan(_level(ramp[names[i - 1]]!)),
          reason: '${names[i]} is not above ${names[i - 1]}, so a surface '
              'meant to sit on top of another would be level with it or under',
        );
      }
    });

    test('lifts a card far enough off the page to be seen', () {
      //ELEVATION HAS NOWHERE ELSE TO COME FROM. AppShadows paints black at 4%
      //alpha, which does nothing over a near-black page, so the only thing
      //telling a card from the page it sits on is this difference. Eight units
      //is the ramp's step; a card is two of them up.
      expect(
        _level(AppColors.darkSurface) - _level(AppColors.darkBackground),
        greaterThanOrEqualTo(0x0C),
      );
    });

    test('and a dialog far enough off a card', () {
      //a dialog sits over cards, not level with them - see dialogTheme
      expect(
        _level(AppColors.darkElevated),
        greaterThan(_level(AppColors.darkSurface)),
      );
    });

    //THE SAME COLOUR, DECIDED TWICE. android:windowBackground paints the
    //window behind the Flutter UI - at launch between the splash handing over
    //and the first frame, and anywhere Flutter does not paint afterwards. It
    //is set in XML, which no Dart token can reach, and it was left at
    //?android:colorBackground: pure #000000 under Theme.Black. So dark mode
    //had a black sheet under a #121212 UI, and lifting the Dart palette off
    //black could not touch it.
    //
    //Hardcoding the hex there is the only option the platform gives, so the
    //guard is this: read the XML back and fail if the two ever disagree.
    group('the Android window behind Flutter', () {
      String windowBackgroundOf(String dir) {
        final file =
            File('android/app/src/main/res/$dir/styles.xml').readAsStringSync();
        //NormalTheme, not LaunchTheme: the launch one is a gradient drawable
        //and deliberately not a flat colour
        final normal = file.substring(file.indexOf('name="NormalTheme"'));
        final match =
            RegExp(r'windowBackground">(#[0-9A-Fa-f]{8})<').firstMatch(normal);
        expect(match, isNotNull,
            reason: '$dir/styles.xml NormalTheme has no literal '
                'windowBackground - if it is back to ?android:colorBackground '
                'it resolves to pure black in dark mode');
        return match!.group(1)!.toUpperCase();
      }

      String hex(Color c) =>
          '#FF${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}';

      for (final dir in ['values-night', 'values-night-v31']) {
        test('$dir matches darkBackground', () {
          expect(windowBackgroundOf(dir), hex(AppColors.darkBackground));
        });
      }

      for (final dir in ['values', 'values-v31']) {
        test('$dir matches lightBackground', () {
          expect(windowBackgroundOf(dir), hex(AppColors.lightBackground));
        });
      }
    });

    //THE RISK THIS CHANGE CARRIED. Lifting the page toward grey reduces its
    //contrast with the text on it, so the thing to prove is that the lift did
    //not spend legibility to buy depth.
    group('still reads', () {
      test('primary text clears AAA on the page and on a card', () {
        for (final surface in [
          AppColors.darkBackground,
          AppColors.darkSurface,
          AppColors.darkElevated,
        ]) {
          expect(_contrast(AppColors.darkTextPrimary, surface),
              greaterThanOrEqualTo(7.0));
        }
      });

      test('secondary text clears AA on the page and on a card', () {
        //4.5:1 is the AA floor for body text. Secondary text is deliberately
        //quieter than primary, so AAA is not the bar for it - but it is the
        //one that gets close, which is why it is checked against every
        //surface it can land on rather than just the darkest.
        for (final surface in [
          AppColors.darkBackground,
          AppColors.darkSurface,
          AppColors.darkElevated,
        ]) {
          expect(_contrast(AppColors.darkTextSecondary, surface),
              greaterThanOrEqualTo(4.5));
        }
      });
    });
  });
}
