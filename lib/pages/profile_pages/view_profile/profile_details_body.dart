//The profile itself: everything below the first photo, drawn identically
//wherever a profile is shown.
//
//SHARED ON PURPOSE. The preview on your own edit page and the page you reach
//by tapping a card in the deck both render this, so a preview is a preview
//rather than a second layout that slowly stops matching. The one thing each
//caller supplies itself is the big photo at the top, because the two frame it
//differently - see the note in view_profile_body.dart.
//
//ORDER, top to bottom:
//  card    name, age and height, bio
//  card    favourite song                   (empty, Spotify later)
//  lines   job, studies, place, languages
//  pills   dating intention, kids, alcohol, smoking, religion, political view
//  card    photo 1 + its story
//  pills   hobbies and interests
//  card    photo 2 + its story
//  card    favourite artists                (empty, Spotify later)
//  pills   traits
//
//Every block disappears when it has nothing to show, so a half-finished
//profile reads as short rather than as broken.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/constants/choice_icons.dart';
import 'package:foitifinder/constants/interest_catalogue.dart';
import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/theme/app_colors.dart';

//shared by every block so a profile has one left edge
const double kProfileSidePadding = 16;
//how much of the screen the photos further down take
const double kProfilePhotoFraction = 0.5;
//and how wide: inset from the edges, so they read as moments in a scroll
//rather than as another full-bleed header
const double _kInlinePhotoWidthFactor = 0.84;
//the picker already caps hobbies at 10; this is the display promise, so a
//profile made before that cap cannot flood the page
const int _kMaxHobbies = 10;

//The whole profile under the header photo.
class ProfileDetailsBody extends StatelessWidget {
  final PublicProfile profile;

  const ProfileDetailsBody({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final hobbies = profile.interestTags.take(_kMaxHobbies).toList();
    final traits = profile.traitTags;
    final photos = profile.photos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderCard(user: profile),
        const SizedBox(height: 12),
        //Spotify's API is not wired up yet, so this is the shape of the answer
        //with nothing in it
        _SoonCard(title: text.myTune),
        const SizedBox(height: 20),
        _Facts(user: profile),
        _Pills(user: profile),

        if (photos.length > 1)
          _PhotoCard(url: photos[1].url, story: photos[1].story),

        if (hobbies.isNotEmpty)
          _TagPills(title: catalogueLabel(text, kGroupHobbies), tags: hobbies),

        if (photos.length > 2)
          _PhotoCard(url: photos[2].url, story: photos[2].story),

        const SizedBox(height: 16),
        _SoonCard(title: text.favouriteArtists),

        if (traits.isNotEmpty)
          _TagPills(title: catalogueLabel(text, kGroupTraits), tags: traits),

        //whatever is left: photos 4, 5 and 6, one after another. The first
        //three are spaced between sections so the page reads as text with
        //pictures in it; past that there is nothing left to space them with.
        for (final photo in photos.skip(3))
          _PhotoCard(url: photo.url, story: photo.story),
      ],
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
      //a block of the right size, not a spinner: nothing below must jump when
      //the image lands
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

//Name, then age and height, then the bio.
class _HeaderCard extends StatelessWidget {
  final PublicProfile user;

  const _HeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    //"24 · 178 cm", with either half missing if it is not set
    final line = [
      if (user.age != null) '${user.age}',
      if (user.heightCm != null) '${user.heightCm} ${text.cm}',
    ].join('  ·  ');
    final bio = (user.bio ?? '').trim();

    return _Card(
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
    );
  }
}

//One of the two Spotify blocks: the title, and a line saying it is not here
//yet. Deliberately the same card as the rest, so when the real content lands
//nothing around it has to move.
class _SoonCard extends StatelessWidget {
  final String title;

  const _SoonCard({required this.title});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.music_note_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text.comingSoon,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

//A photo further down the page, with its story under it IN THE SAME CARD: the
//caption belongs to that photo, and putting it in its own block would leave it
//floating between two images with nothing to tie it to either.
class _PhotoCard extends StatelessWidget {
  final String url;
  final String? story;

  const _PhotoCard({required this.url, this.story});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height * kProfilePhotoFraction;
    final hasStory = (story ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: _kInlinePhotoWidthFactor,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: height,
                  child: _Photo(url: url),
                ),
                if (hasStory)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Text(
                      story!.trim(),
                      style: theme.textTheme.bodyMedium,
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

//Job, studies, place, languages - plain lines on the background, each one
//simply absent when it has no value. An empty profile shows nothing here
//rather than a list of blanks.
class _Facts extends StatelessWidget {
  final PublicProfile user;

  const _Facts({required this.user});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    //"Applied Informatics · University of Macedonia", or whichever half exists
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
      //under the job, because it answers the same question
      if ((user.volunteering ?? '').trim().isNotEmpty)
        (Icons.volunteer_activism_outlined, user.volunteering!.trim()),
      if (studies.isNotEmpty) (Icons.school_outlined, studies),
      if ((user.city ?? '').trim().isNotEmpty)
        (Icons.location_on_outlined, catalogueLabel(text, user.city!.trim())),
      if (languages.isNotEmpty) (Icons.translate_outlined, languages),
    ];

    if (facts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kProfileSidePadding + 4,
        0,
        kProfileSidePadding + 4,
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

//The answers that read as facts about someone: the four single ones, then the
//two lists. Religion and political view can hold several answers each, so they
//contribute one pill per pick - all carrying the same icon, since the icon
//names the subject rather than the answer.
class _Pills extends StatelessWidget {
  final PublicProfile user;

  const _Pills({required this.user});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;

    const order = [
      kChoiceDatingIntention,
      kChoiceKids,
      kChoiceAlcohol,
      kChoiceSmoking,
      kChoiceReligion,
      kChoicePoliticalView,
      kChoiceSexualOrientation,
    ];

    final answers = <(IconData?, String)>[
      for (final choice in order)
        for (final answer in user.choice(choice.key))
          (iconForChoice(choice), catalogueLabel(text, answer)),
    ];

    if (answers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(kProfileSidePadding, 12, kProfileSidePadding, 0),
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

//Hobbies or traits: the same pills, no icons and no card - they are a cloud of
//words on the background, which is what keeps them from competing with the
//answers above.
class _TagPills extends StatelessWidget {
  final String title;
  final List<String> tags;

  const _TagPills({required this.title, required this.tags});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(kProfileSidePadding, 16, kProfileSidePadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //Not the purple SectionHeader the edit side uses: there a header
          //labels a list of controls, here it labels content, and a row of
          //coloured headings would pull the eye past the profile itself.
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                _Pill(icon: null, label: catalogueLabel(text, tag)),
            ],
          ),
        ],
      ),
    );
  }
}

//The card every block shares: same fill, same radius, same side padding.
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kProfileSidePadding),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: child,
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
