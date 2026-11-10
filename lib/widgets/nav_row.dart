//The building blocks of the profile / edit-profile lists: a section heading, a
//card that groups rows, and the rows themselves.
//
//Shared rather than duplicated per page: these appear on the profile page, the
//edit profile page and (eventually) everywhere else with a settings-style list,
//and three copies would drift apart within a week.

import 'package:flutter/material.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/app_switch.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:foitifinder/widgets/pressable.dart';

//A heading above a run of related rows.
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        //bigger than the 16px row labels underneath (titleMedium), so a
        //header reads as the heading of its rows rather than one of them
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: 18,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

//The filled, rounded card that a run of rows sits in - same treatment as the
//settings page.
class CardGroup extends StatelessWidget {
  final List<Widget> children;
  //hairlines between the rows. Opt-in rather than always-on: a card holding a
  //single row has nothing to separate, and short cards read fine without them.
  final bool dividers;

  const CardGroup({
    super.key,
    required this.children,
    this.dividers = false,
  });

  //children with a Divider between each pair - never before the first or after
  //the last, where it would collide with the card's rounded edge
  List<Widget> _withDividers() {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        out.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
      out.add(children[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Material(
          //Material lerps its colour over kThemeChangeDuration whenever the
          //resolved value changes, so any momentary theme difference during a
          //route transition is ANIMATED THROUGH rather than applied instantly -
          //which is what turns a colour blip into a visible sweep. These cards
          //never intentionally change colour, so nothing is lost by making the
          //change instant.
          animationDuration: Duration.zero,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            side: BorderSide.none,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          //so a pressed row's tint follows the rounded corners instead of
          //squaring them off at the top and bottom of the card
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: dividers ? _withDividers() : children,
          ),
        ),
      ),
    );
  }
}

//One row inside a CardGroup: optional icon, label, optional summary of the
//current answer, chevron.
class NavRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  //the current answer, shown greyed on the right. Empty renders nothing.
  final String trailing;
  final VoidCallback onTap;

  const NavRow({
    super.key,
    this.icon,
    required this.label,
    this.trailing = '',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SpringPress(
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 24),
                const SizedBox(width: 16),
              ],
              Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
              if (trailing.isNotEmpty)
                //capped so a long answer truncates instead of shoving the
                //chevron off the edge
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 144),
                  child: Text(
                    trailing,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: mutedText(context),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: mutedInk(context)),
            ],
          ),
        ),
      ),
    );
  }
}

//A row with a switch at the end. The label wraps rather than pushing the
//switch off the card.
class SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(width: 16),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

//One answer in a list of them, with a check that springs in when it is picked.
class CheckRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CheckRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: SpringPress(
        child: Pressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: AppMotion.base,
                  curve: AppMotion.emphasized,
                  child: Image.asset(
                    'assets/icons/check.png',
                    width: 24,
                    height: 24,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
