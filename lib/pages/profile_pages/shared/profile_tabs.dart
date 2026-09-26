//The Edit / View pair that sits where an app bar title normally goes, with a
//line under whichever one you are on.
//
//Not a TabBar, and not a TabBarView: the two sides are separate PAGES, pushed
//and popped, so each keeps its own scroll position and its own state, and the
//view side can be opened from anywhere later. A TabBarView would force both to
//live in one widget and rebuild together.
//
//The indicator is positioned from MEASURED text widths rather than by giving
//the labels equal space. "Edit" and "View" are different lengths, and in Greek
//they are very different lengths («Επεξεργασία» / «Προβολή»), so an even split
//would leave the line obviously wider than the word it belongs to.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';

enum ProfileTab { edit, view }

class ProfileTabs extends StatelessWidget {
  final ProfileTab selected;
  //called only for the tab that is NOT selected; tapping the current one does
  //nothing rather than pushing a second copy of the page you are on
  final VoidCallback onSwitch;

  const ProfileTabs({
    super.key,
    required this.selected,
    required this.onSwitch,
  });

  //gap between the two words
  static const double _gap = 20;
  static const double _lineHeight = 2.5;
  static const Duration _slide = Duration(milliseconds: 260);

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

    final labels = {
      ProfileTab.edit: text.tabEdit,
      ProfileTab.view: text.tabView,
    };
    final editWidth = _widthOf(context, labels[ProfileTab.edit]!, style);
    final viewWidth = _widthOf(context, labels[ProfileTab.view]!, style);

    final isEdit = selected == ProfileTab.edit;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tab in ProfileTab.values) ...[
              GestureDetector(
                //the whole word, including its padding, not just the glyphs
                behavior: HitTestBehavior.opaque,
                onTap: tab == selected ? null : onSwitch,
                child: AnimatedDefaultTextStyle(
                  duration: _slide,
                  style: style.copyWith(
                    //the one you are not on recedes rather than disappearing:
                    //it has to stay readable to be worth tapping
                    color: tab == selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                  child: Text(labels[tab]!),
                ),
              ),
              if (tab != ProfileTab.values.last) const SizedBox(width: _gap),
            ],
          ],
        ),
        const SizedBox(height: 6),
        //the line, as wide as the word above it, sliding between the two
        SizedBox(
          width: editWidth + _gap + viewWidth,
          height: _lineHeight,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: _slide,
                curve: Curves.easeOutCubic,
                left: isEdit ? 0 : editWidth + _gap,
                width: isEdit ? editWidth : viewWidth,
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
