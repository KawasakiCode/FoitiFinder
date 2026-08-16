//Page where the user picks the interests shown on their profile.
//
//Breeze-style, three levels deep:
//  group    -> the 5 broad blocks (Hobbies & interests, Traits, Bio, Q&A's,
//              Matching pools)
//  section  -> the subcategory inside a group (Activities, Music, MBTI, ...)
//  option   -> the actual tappable box
//
//Two different budget rules, because the groups behave differently:
//  * "Hobbies & interests" has ONE shared budget of 10 spread across all seven
//    of its sections — spending a pick on Music takes one away from Sports.
//  * every other group is capped per section (MBTI 1, the rest 3).
//Picking 0 anywhere is fine.
//
//UI ONLY: nothing here talks to a provider, the API or the user model. The
//selection lives in _selected and save() just hands it back to the caller.
//
//NAMING WARNING: UserModel.interests already exists and means something else —
//it is the comma separated gender preference ("Men"/"Women"/"Everyone") read by
//interests_to_genders() in the backend. These tags are a separate concept and
//must NOT be persisted into that column. Pick a distinct name (e.g.
//interest_tags / hobbies) when the backend side is added.

import 'package:flutter/material.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/primary_button.dart';

//A subcategory: a title and the boxes under it.
class InterestSection {
  final String title;
  final List<String> options;
  //per-section cap. Ignored when the parent group has a shared budget.
  //A section with max 1 behaves like a radio: tapping a different box swaps the
  //pick instead of being refused, which is what you want for MBTI.
  final int maxSelections;

  const InterestSection(this.title, this.options, {this.maxSelections = 3});
}

//One of the 5 broad blocks.
class InterestGroup {
  final String title;
  final List<InterestSection> sections;
  //when set, every section in this group draws from this one budget
  final int? sharedMax;
  //shown instead of the sections while a group has no content yet
  final String? placeholder;

  const InterestGroup(
    this.title, {
    this.sections = const [],
    this.sharedMax,
    this.placeholder,
  });
}

//The catalogue. Kept in this file while it's still being shaped; move it to
//lib/constants/ once it settles.
//TODO: these labels are hardcoded English — the app ships Greek too, so they
//need to move to app_en.arb / app_el.arb before this page goes live.
const List<InterestGroup> kInterestGroups = [
  //=========================================================================
  //1. HOBBIES & INTERESTS — 7 sections sharing a budget of 10
  //=========================================================================
  InterestGroup(
    'Hobbies & interests',
    sharedMax: 10,
    sections: [
      InterestSection('Activities', [
        'Backpacking',
        'Baking',
        'Beach',
        'Camping',
        'City trips',
        'Concerts',
        'Cooking',
        'Cosplay',
        'Dining out',
        'Dinner parties',
        'Escape rooms',
        'Festivals',
        'Having drinks',
        'Hiking',
        'Karaoke',
        'Meditation',
        'Mountains',
        'Museum',
        'Outdoors',
        'Party',
        'Pub quiz',
        'Resort vacations',
        'Road trips',
        'Sauna',
        'Shopping',
        'Taking a walk',
        'Thrifting',
        'Travel',
        'Wellness',
      ]),
      InterestSection('Interests', [
        'Programming',
        'AI',
        'Animals',
        'Architecture',
        'Art',
        'Biology',
        'Cars',
        'Cats',
        'Cinema',
        'Dogs',
        'Entrepreneurship',
        'Finance',
        'Formula 1',
        'History',
        'Horses',
        'Language',
        'Nature',
        'Personal development',
        'Philosophy',
        'Plants',
        'Politics',
        'Psychology',
        'Science',
        'Sneakers',
        'Sustainability',
        'Tattoos',
        'Tech',
        'Theatre',
      ]),
      InterestSection('Entertainment', [
        'Reading',
        'Anime',
        'Board games',
        'Cartoons',
        'Chess',
        'Comedy',
        'Comics',
        'Disney',
        'Documentaries',
        'Fantasy',
        'Gaming',
        'Horror',
        'Memes',
        'Movies',
        'Musicals',
        'Netflix',
        'Podcasts',
        'Puzzles',
        'Sci-fi',
        'Sitcoms',
        'True crime',
        'Vinyl records',
        'YouTube',
      ]),
      InterestSection('Creative', [
        'Playing instruments',
        'Acting',
        'Composing music',
        'Crafts',
        'DIY',
        'Design',
        'Drawing',
        'Fashion',
        'Knitting',
        'Painting',
        'Photography',
        'Poetry',
        'Pottery',
        'Sewing',
        'Singing',
        'Writing',
      ]),
      InterestSection('Music', [
        'Classical music',
        'Afro beats',
        'Blues',
        'Country music',
        'DJing',
        'Dancehall',
        'Disco',
        'Drum and bass',
        'Drums',
        'Dubstep',
        'EDM',
        'Funk',
        'Guitar',
        'Hardstyle',
        'Hiphop',
        'House',
        'Indie music',
        'Jazz',
        'K-pop',
        'Latin music',
        'Metal',
        'Piano',
        'Pop music',
        'Punk',
        'R&B',
        'Rap',
        'Reggae',
        'Reggaeton',
        'Rock',
        'Salsa',
        'Soul',
        'Techno',
      ]),
      InterestSection('Food & drinks', [
        'BBQ',
        'Beer',
        'Biryani',
        'Boba',
        'Champagne',
        'Charcuterie',
        'Cheese',
        'Chocolate',
        'Cocktails',
        'Coffee',
        'Craft beers',
        'Curry',
        'Empanada',
        'Falafel',
        'Hot pot',
        'Jollof',
        'Matcha',
        'Pasta',
        'Pizza',
        'Pubs',
        'Ramen',
        'Roti',
        'Sushi',
        'Tapas',
        'Tea',
        'Whiskey',
        'Wine',
      ]),
      InterestSection('Sports', [
        'Martial arts',
        'Kick(boxing)',
        'Athletics',
        'Badminton',
        'Ballet',
        'Baseball',
        'Basketball',
        'Bouldering',
        'Bowling',
        'Climbing',
        'Cricket',
        'Cross-training',
        'Cycling',
        'Dancing',
        'Extreme sports',
        'Fencing',
        'Fitness',
        'Football',
        'Golf',
        'Handball',
        'Hockey',
        'Horse riding',
        'Ice skating',
        'Kayaking',
        'Kitesurfing',
        'Motorcycling',
        'Mountainbiking',
        'Padel',
        'Pickleball',
        'Pilates',
        'Rowing',
        'Rugby',
        'Running',
        'SUP',
        'Sailing',
        'Scuba diving',
        'Skateboarding',
        'Skiing',
        'Snowboarding',
        'Spikeball',
        'Squash',
        'Surfing',
        'Swimming',
        'Table tennis',
        'Tennis',
        'Volleyball',
        'Waterpolo',
        'Windsurfing',
        'Yoga',
      ]),
    ],
  ),

  //=========================================================================
  //2. TRAITS — capped per section. Gender and age range are deliberately
  //absent: they already live in settings.
  //=========================================================================
  InterestGroup(
    'Traits',
    sections: [
      InterestSection('MBTI', [
        'INTJ',
        'INTP',
        'ENTJ',
        'ENTP',
        'INFJ',
        'INFP',
        'ENFJ',
        'ENFP',
        'ISTJ',
        'ISFJ',
        'ESTJ',
        'ESFJ',
        'ISTP',
        'ISFP',
        'ESTP',
        'ESFP',
      ], maxSelections: 1),
      InterestSection('Relationship goals', [
        'Long-term relationship',
        'Life partner',
        'Short-term fun',
        'Casual dating',
        'New friends',
        'Still figuring it out',
        'Open to anything',
      ]),
      InterestSection('Family plans', [
        'Want kids someday',
        "Don't want kids",
        'Have kids',
        'Open to kids',
        'Not sure yet',
      ]),
      InterestSection('Drinking & smoking', [
        'Social drinker',
        'Rarely drinks',
        'Sober',
        'Non-smoker',
        'Social smoker',
        'Regular smoker',
        'Vaper',
        '420 friendly',
      ]),
      InterestSection('Beliefs & values', [
        'Spiritual',
        'Orthodox',
        'Christian',
        'Muslim',
        'Jewish',
        'Atheist',
        'Agnostic',
        'Environmentalist',
        'Feminist',
        'Volunteering',
        'Activism',
        'Politically engaged',
        'Apolitical',
      ]),
      InterestSection('Languages', [
        'Greek',
        'English',
        'German',
        'French',
        'Spanish',
        'Italian',
        'Albanian',
        'Bulgarian',
        'Romanian',
        'Russian',
        'Turkish',
        'Arabic',
        'Sign language',
      ]),
    ],
  ),

  //=========================================================================
  //3-5. Declared but empty — these are free text / their own mechanic, not
  //boxes, so they need a different widget than the chip grid above.
  //=========================================================================
  InterestGroup(
    'Bio',
    placeholder: 'Free text — needs a text field, not boxes.',
  ),
  InterestGroup(
    "Q&A's",
    placeholder: 'Prompt + answer pairs. Catalogue of questions still to come.',
  ),
  InterestGroup(
    'Matching pools',
    placeholder: 'Joinable pools. Needs its own list once the pools are defined.',
  ),
];

class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key});

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  //"group/section" -> the options picked in it, in tap order (order matters if
  //we ever show only the first few on a profile card)
  final Map<String, List<String>> _selected = {};

  String _keyFor(InterestGroup group, InterestSection section) =>
      '${group.title}/${section.title}';

  //read-only: never creates the entry, so calling it from build() can't mutate
  //state. toggleInterest is the only thing that writes.
  List<String> picksIn(InterestGroup group, InterestSection section) =>
      _selected[_keyFor(group, section)] ?? const [];

  //every pick in a group, across all its sections — this is what the shared
  //budget is measured against
  int groupCount(InterestGroup group) => group.sections.fold(
        0,
        (sum, section) => sum + picksIn(group, section).length,
      );

  bool isSelected(InterestGroup group, InterestSection section, String option) =>
      picksIn(group, section).contains(option);

  //whether a *new* pick would be refused. Single-pick sections are never full:
  //tapping another box swaps the choice instead.
  bool isFull(InterestGroup group, InterestSection section) {
    if (section.maxSelections == 1) return false;
    if (group.sharedMax != null) return groupCount(group) >= group.sharedMax!;
    return picksIn(group, section).length >= section.maxSelections;
  }

  void toggleInterest(
    InterestGroup group,
    InterestSection section,
    String option,
  ) {
    setState(() {
      final picks = _selected.putIfAbsent(_keyFor(group, section), () => []);

      //tapping something already picked always removes it, even when full
      if (picks.remove(option)) return;

      //radio sections (MBTI): the new pick replaces the old one. Done before
      //the budget check so a swap can't be blocked by a full group.
      if (section.maxSelections == 1) {
        picks
          ..clear()
          ..add(option);
        return;
      }

      //shared budget beats the per-section cap when the group has one
      if (group.sharedMax != null) {
        if (groupCount(group) >= group.sharedMax!) return;
      } else if (picks.length >= section.maxSelections) {
        return;
      }

      picks.add(option);
    });
  }

  //every pick on the page, flattened
  List<String> get allSelected => [
        for (final group in kInterestGroups)
          for (final section in group.sections) ...picksIn(group, section),
      ];

  //TODO: persist once the backend field exists. Local-only on purpose for now.
  void save() {
    Navigator.of(context).pop({
      for (final entry in _selected.entries)
        if (entry.value.isNotEmpty) entry.key: List<String>.unmodifiable(entry.value),
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = allSelected.length;

    return Scaffold(
      appBar: AppBar(
        //TODO: move to l10n along with the catalogue labels
        title: const Text('Interests'),
        automaticallyImplyLeading: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: kInterestGroups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 36),
        itemBuilder: (context, index) =>
            _GroupBlock(group: kInterestGroups[index], state: this),
      ),
      //save bar sits outside the list so it never covers the last group
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: PrimaryButton(
          label: total == 0 ? 'Save' : 'Save $total selected',
          onPressed: save,
        ),
      ),
    );
  }
}

//One of the 5 broad blocks: its title, the shared counter if it has one, and
//every section underneath.
class _GroupBlock extends StatelessWidget {
  final InterestGroup group;
  final _InterestsPageState state;

  const _GroupBlock({required this.group, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                group.title,
                style: theme.textTheme.headlineMedium?.copyWith(fontSize: 22),
              ),
            ),
            //the shared budget lives on the group header, since no single
            //section owns it
            if (group.sharedMax != null)
              Text(
                '${state.groupCount(group)}/${group.sharedMax}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
              ),
          ],
        ),
        if (group.placeholder != null) ...[
          const SizedBox(height: 8),
          Text(group.placeholder!, style: theme.textTheme.bodySmall),
        ],
        for (final section in group.sections) ...[
          const SizedBox(height: 20),
          _SectionBlock(group: group, section: section, state: state),
        ],
      ],
    );
  }
}

//A section title with its counter (only when the section owns its own cap) and
//the boxes underneath.
class _SectionBlock extends StatelessWidget {
  final InterestGroup group;
  final InterestSection section;
  final _InterestsPageState state;

  const _SectionBlock({
    required this.group,
    required this.section,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool sharesBudget = group.sharedMax != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
              ),
            ),
            //a per-section "2/3" would be a lie when the budget is shared, so
            //it's only drawn when the section really owns its cap
            if (!sharesBudget)
              Text(
                '${state.picksIn(group, section).length}/${section.maxSelections}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in section.options)
              _InterestBox(
                label: option,
                selected: state.isSelected(group, section, option),
                //greyed out once there's no room left, but still tappable to
                //deselect if it's one of the picked ones
                dimmed: state.isFull(group, section) &&
                    !state.isSelected(group, section, option),
                onTap: () => state.toggleInterest(group, section, option),
              ),
          ],
        ),
      ],
    );
  }
}

//One tappable pill.
//Selected fills invert with the theme: white box in dark mode, near-black box
//in light mode, with the label flipped to match so it stays readable.
class _InterestBox extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _InterestBox({
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
