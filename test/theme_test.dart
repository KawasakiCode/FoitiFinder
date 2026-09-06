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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
