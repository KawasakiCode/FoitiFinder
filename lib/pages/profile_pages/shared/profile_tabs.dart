//The Edit / View pair in the middle of the app bar, with a line under
//whichever side the body is showing.
//
//THE APP BAR NEVER MOVES. Edit and View are two pages of one PageView inside a
//single Scaffold, so switching slides the BODY under a header that stays put.
//Two separate routes would have slid the whole screen, header and all.
//
//The line is driven by [progress], the PageView's own position (0 = Edit,
//1 = View, and every fraction in between), so it tracks the body exactly
//instead of running its own animation that merely looks similar.
//
//Widths are MEASURED rather than split evenly. "Edit" and "View" differ, and
//in Greek they differ a lot («Επεξεργασία» / «Προβολή»), so an even split
//would leave the line obviously wider than the word it belongs to.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';

class ProfileTabs extends StatelessWidget {
  //0 = Edit, 1 = View. Fractions are mid-slide.
  final double progress;
  final ValueChanged<int> onSelect;

  const ProfileTabs({super.key, required this.progress, required this.onSelect});

  //gap between the two words
  static const double _gap = 20;
  static const double _lineHeight = 2.5;

  double _widthOf(BuildContext context, String label, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final style = theme.textTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.w700,
    );

    final labels = [text.tabEdit, text.tabView];
    final widths = [
      _widthOf(context, labels[0], style),
      _widthOf(context, labels[1], style),
    ];

    final t = progress.clamp(0.0, 1.0);
    //the line walks from under one word to under the other, and resizes on the
    //way, so it always ends the width of the word it lands on
    final left = t * (widths[0] + _gap);
    final width = widths[0] + (widths[1] - widths[0]) * t;

    final onSurface = theme.colorScheme.onSurface;
    //the side you are not on recedes rather than disappearing: it has to stay
    //readable to be worth tapping
    const double dim = 0.38;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              GestureDetector(
                //the whole word, including its padding, not just the glyphs
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Text(
                  labels[i],
                  style: style.copyWith(
                    //fades with the slide, so neither side snaps
                    color: onSurface.withValues(
                      alpha: dim + (1 - dim) * (i == 0 ? 1 - t : t),
                    ),
                  ),
                ),
              ),
              if (i == 0) const SizedBox(width: _gap),
            ],
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: widths[0] + _gap + widths[1],
          height: _lineHeight,
          child: Stack(
            children: [
              Positioned(
                left: left,
                width: width,
                height: _lineHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(_lineHeight),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
