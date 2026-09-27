//The profile as other people see it - the View half of the edit page.
//
//A BODY, NOT A PAGE: no Scaffold and no app bar, because it lives inside the
//edit page's PageView. That is what lets the header stay still while this
//slides in beneath it.
//
//READ-ONLY, AND READS FROM ProfileProvider. Nothing here has its own copy of
//anything: every value comes from the same user object the edit side saves
//into, so the preview cannot show something the profile does not have. Edit a
//tag, swipe across, and it is already right.
//
//LAYOUT, top to bottom:
//  photo 0, full width, 45% of the screen
//  a card lifted over the bottom of the photo: name, age and height, bio
//  plain lines on the background: job, studies, place, languages
//  pills: dating intention, kids, alcohol, smoking
//
//The pills are the same shape as the interest boxes in the tag pages, but not
//InterestBox itself - that one is a control, with selection, dimming and a tap
//target. These are read-only labels, so they only borrow its look.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/constants/choice_icons.dart';
import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/utils/age.dart';
import 'package:provider/provider.dart';

class ViewProfileBody extends StatelessWidget {
  const ViewProfileBody({super.key});

  //how much of the screen the photo takes
  static const double _photoFraction = 0.45;
  //how far the card is lifted over the bottom of the photo
  static const double _cardOverlap = 28;
  static const double _sidePadding = 16;

  @override
  Widget build(BuildContext context) {
    //watch, not read: a save on the edit side must redraw this
    final user = Provider.of<ProfileProvider>(context).currentUser;
    if (user == null) return const SizedBox.shrink();

    final photoHeight = MediaQuery.sizeOf(context).height * _photoFraction;

    return SingleChildScrollView(
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: photoHeight,
            child: _Photo(url: user.profilePictureUrl),
          ),
          //the card and everything under it start one overlap ABOVE the
          //bottom of the photo, so the card's top edge crops into it
          Padding(
            padding: EdgeInsets.only(top: photoHeight - _cardOverlap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(user: user),
                const SizedBox(height: 20),
                _Facts(user: user),
                _Pills(user: user),
                //room to scroll past the last pill
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//Photo 0, or a neutral block when there is none. A profile without photos is
//only reachable mid-signup, but an empty box beats a crash.
class _Photo extends StatelessWidget {
  final String? url;

  const _Photo({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    if (url == null) return placeholder;

    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      //a block of the right size, not a spinner: the card below must not jump
      //when the image lands
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

//Name, then age and height, then the bio.
class _HeaderCard extends StatelessWidget {
  final UserModel user;

  const _HeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final age = ageFromBirthday(user.birthday);
    //"24 · 178 cm", with either half missing if it is not set
    final line = [
      if (age != null) '$age',
      if (user.heightCm != null) '${user.heightCm} ${text.cm}',
    ].join('  ·  ');
    final bio = (user.bio ?? '').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ViewProfileBody._sidePadding,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (line.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                line,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(bio, style: theme.textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}

//Job, studies, place, languages - plain lines on the background, each one
//simply absent when it has no value. An empty profile shows nothing here
//rather than a list of blanks.
class _Facts extends StatelessWidget {
  final UserModel user;

  const _Facts({required this.user});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    //"Applied Informatics at University of Macedonia", or whichever half exists
    final studies = [
      if ((user.major ?? '').trim().isNotEmpty) user.major!.trim(),
      if ((user.university ?? '').trim().isNotEmpty) user.university!.trim(),
    ].join(' · ');

    final languages = user.languagesSpoken
        .map((language) => catalogueLabel(text, language))
        .join(', ');

    final facts = <(IconData, String)>[
      if ((user.job ?? '').trim().isNotEmpty)
        (Icons.work_outline, user.job!.trim()),
      if (studies.isNotEmpty) (Icons.school_outlined, studies),
      if ((user.city ?? '').trim().isNotEmpty)
        (Icons.location_on_outlined, catalogueLabel(text, user.city!.trim())),
      if (languages.isNotEmpty) (Icons.translate_outlined, languages),
    ];

    if (facts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ViewProfileBody._sidePadding + 4,
        0,
        ViewProfileBody._sidePadding + 4,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, value) in facts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(value, style: theme.textTheme.bodyLarge),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

//Dating intention, kids, alcohol, smoking - the four single answers that read
//as facts about someone rather than as sentences.
class _Pills extends StatelessWidget {
  final UserModel user;

  const _Pills({required this.user});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;

    const order = [
      kChoiceDatingIntention,
      kChoiceKids,
      kChoiceAlcohol,
      kChoiceSmoking,
    ];

    //an icon per category, because three of these four share the same words -
    //see constants/choice_icons.dart
    final answers = <(IconData?, String)>[
      for (final choice in order)
        if (user.choice(choice.key).isNotEmpty)
          (
            iconForChoice(choice),
            catalogueLabel(text, user.choice(choice.key).first),
          ),
    ];

    if (answers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ViewProfileBody._sidePadding,
        12,
        ViewProfileBody._sidePadding,
        0,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (icon, label) in answers) _Pill(icon: icon, label: label),
        ],
      ),
    );
  }
}

//The idle state of InterestBox, without the control around it.
class _Pill extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
