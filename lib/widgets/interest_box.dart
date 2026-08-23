//One tappable interest pill, shared by every page that shows the catalogue.
//
//Selected fills invert with the theme: white box in dark mode, near-black box
//in light mode, with the label flipped to match so it stays readable.

import 'package:flutter/material.dart';
import 'package:foitifinder/theme/app_colors.dart';

class InterestBox extends StatelessWidget {
  final String label;
  final bool selected;
  //greyed out when there's no room left for a NEW pick. Still tappable, so an
  //already-picked box can always be removed.
  final bool dimmed;
  final VoidCallback onTap;

  const InterestBox({
    super.key,
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color selectedFill =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color selectedLabel =
        isDark ? AppColors.lightTextPrimary : AppColors.darkTextPrimary;
    final Color idleFill = theme.colorScheme.surface;
    final Color idleLabel =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Opacity(
      //only the unpickable ones fade, so a full section still reads clearly
      opacity: dimmed ? 0.4 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? selectedFill : idleFill,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected ? selectedFill : border,
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selected ? selectedLabel : idleLabel,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
