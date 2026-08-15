//Page where the user picks the interests shown on their profile.
//
//Breeze-style: the catalogue is split into named categories and you tap the
//boxes you like. Each category is capped on its own (3 for now) rather than
//having one global budget, so a pick in "Music" never costs you a pick in
//"Sports". Picking 0 in a category is fine.
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

//One block of the page: a title and the boxes underneath it.
class InterestCategory {
  final String title;
  final List<String> options;
  //per-category cap. All 3 for now, but some categories are logically
  //single-answer (family plans, star sign if it ever lands) — flip those to 1
  //here instead of adding a special case in the widget.
  final int maxSelections;

  const InterestCategory(this.title, this.options, {this.maxSelections = 3});
}

//The catalogue. Kept in this file while it's still being shaped; move it to
//lib/constants/ once it settles.
//TODO: these labels are hardcoded English — the app ships Greek too, so they
//need to move to app_en.arb / app_el.arb before this page goes live.
const List<InterestCategory> kInterestCategories = [
  //---- Profile basics (the "standard" ones). Gender and age range are
  //deliberately absent: they already live in settings.
  InterestCategory('Relationship goals', [
    'Long-term relationship',
    'Life partner',
    'Short-term fun',
    'Casual dating',
    'New friends',
    'Still figuring it out',
    'Open to anything',
  ]),
  InterestCategory('MBTI', [

  ]),
  InterestCategory('Family plans', [
    'Want kids someday',
    "Don't want kids",
    'Have kids',
    'Open to kids',
    'Not sure yet',
  ]),
  InterestCategory('Drinking & smoking', [
    'Social drinker',
    'Rarely drinks',
    'Sober',
    'Non-smoker',
    'Social smoker',
    'Regular smoker',
    'Vaper',
    '420 friendly',
  ]),
  InterestCategory('Religion', [
    'Spiritual',
    'Orthodox',
    'Christian',
    'Muslim',
    'Jewish',
    'Atheist',
    'Agnostic'
  ]),
  InterestCategory('Languages', [
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

  //---- Interests proper
  InterestCategory('Sports & movement', [
    'Football',
    'Basketball',
    'Volleyball',
    'Running',
    'Gym',
    'CrossFit',
    'Yoga',
    'Pilates',
    'Climbing',
    'Swimming',
    'Surfing',
    'Sailing',
    'Skiing',
    'Snowboarding',
    'Tennis',
    'Padel',
    'Martial arts',
    'Cycling',
    'Dancing',
    'Water polo',
    'Track & field',
  ]),
  InterestCategory('Outdoors & travel', [
    'Hiking',
    'Camping',
    'Road trips',
    'Island hopping',
    'Beach days',
    'Backpacking',
    'City breaks',
    'Mountaineering',
    'Kayaking',
    'Fishing',
    'Stargazing',
    'Festivals abroad',
  ]),
  InterestCategory('Creativity & making', [
    'Photography',
    'Painting',
    'Drawing',
    'Graphic design',
    'Writing',
    'Poetry',
    'Playing an instrument',
    'Singing',
    'Producing music',
    'DJing',
    'Filmmaking',
    'Theatre',
    'Pottery',
    'Knitting',
    'Sewing',
    'DIY',
    '3D printing',
    'Woodworking',
  ]),
  InterestCategory('Music', [
    'Rock',
    'Indie',
    'Hip hop',
    'Rap',
    'R&B',
    'Pop',
    'K-pop',
    'Metal',
    'Punk',
    'Jazz',
    'Blues',
    'Classical',
    'Techno',
    'House',
    'Trance',
    'Drum & bass',
    'Reggaeton',
    'Latin',
    'Folk',
    'Greek traditional',
    'Rebetiko',
    'Laika',
    'Live gigs',
    'Vinyl',
  ]),
  InterestCategory('Film & TV', [
    'Cinema',
    'Sci-fi',
    'Fantasy',
    'Horror',
    'Thrillers',
    'Comedy',
    'Rom-coms',
    'Documentaries',
    'Anime',
    'K-dramas',
    'Reality TV',
    'Arthouse',
    'Marvel',
    'True crime',
    'Series binging',
  ]),
  InterestCategory('Food & drink', [
    'Cooking',
    'Baking',
    'Brunch',
    'Street food',
    'Souvlaki runs',
    'Sushi',
    'Vegan',
    'Vegetarian',
    'Coffee',
    'Frappe',
    'Specialty coffee',
    'Wine',
    'Craft beer',
    'Cocktails',
    'Tsipouro',
    'Barbecue',
    'New restaurants',
  ]),
  InterestCategory('Going out', [
    'Bars',
    'Clubbing',
    'Live music',
    'Bouzoukia',
    'Raves',
    'Karaoke',
    'Pub quiz',
    'Board game cafes',
    'Concerts',
    'Theatre nights',
    'Festivals',
    'Beach bars',
    'Late night walks',
  ]),
  InterestCategory('Staying in', [
    'Board games',
    'Card games',
    'Cooking at home',
    'Movie nights',
    'Puzzles',
    'Journaling',
    'Podcasts',
    'Reading in bed',
    'Gardening',
    'Home workouts',
    'Napping',
  ]),
  InterestCategory('Gaming & tech', [
    'PC gaming',
    'Console gaming',
    'Mobile games',
    'Esports',
    'Retro games',
    'Chess',
    'D&D',
    'Tabletop RPGs',
    'Coding',
    'Robotics',
    'AI',
    'Crypto',
    'Gadgets',
    'Streaming',
    'Speedrunning',
  ]),
  InterestCategory('Reading & learning', [
    'Fiction',
    'Non-fiction',
    'Fantasy books',
    'Sci-fi books',
    'Philosophy',
    'Psychology',
    'History',
    'Manga',
    'Comics',
    'Book clubs',
    'Languages',
    'Debating',
  ]),
  InterestCategory('Pets & animals', [
    'Dog person',
    'Cat person',
    'Has a dog',
    'Has a cat',
    'Wants a pet',
    'Horse riding',
    'Bird watching',
    'Aquariums',
    'Animal volunteering',
    'Allergic to pets',
  ]),
  InterestCategory('Student life', [
    'Study dates',
    'Library sessions',
    'Erasmus',
    'Student parties',
    'Uni sports teams',
    'Student societies',
    'Volunteering',
    'Part-time job',
    'Thesis survival',
    'All-nighters',
    'Campus coffee',
    'Group projects',
  ]),
];

class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key});

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  //category title -> the options picked in it, in tap order (order matters if
  //we ever show only the first few on a profile card)
  final Map<String, List<String>> _selected = {};

  //read-only: never creates the entry, so calling it from build() can't mutate
  //state. toggleInterest is the only thing that writes.
  List<String> _picksIn(InterestCategory category) =>
      _selected[category.title] ?? const [];

  bool isSelected(InterestCategory category, String option) =>
      _picksIn(category).contains(option);

  //a category is full once it hits its own cap — other categories are unaffected
  bool isCategoryFull(InterestCategory category) =>
      _picksIn(category).length >= category.maxSelections;

  //tapping a picked box always removes it; tapping a new one only lands if the
  //category still has room, so the cap can never be exceeded
  void toggleInterest(InterestCategory category, String option) {
    setState(() {
      final picks = _selected.putIfAbsent(category.title, () => []);
      if (picks.remove(option)) return;
      if (picks.length >= category.maxSelections) return;
      picks.add(option);
    });
  }

  //every pick across every category, flattened
  List<String> get allSelected =>
      [for (final category in kInterestCategories) ..._picksIn(category)];

  //TODO: persist once the backend field exists. Local-only on purpose for now.
  void save() {
    Navigator.of(context).pop(
      //copy, so the caller can't mutate our state
      {for (final entry in _selected.entries) entry.key: List<String>.unmodifiable(entry.value)},
    );
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
        itemCount: kInterestCategories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 28),
        itemBuilder: (context, index) =>
            _CategoryBlock(category: kInterestCategories[index], state: this),
      ),
      //save bar sits outside the list so it never covers the last category
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

//A category title with its counter, and the boxes underneath.
class _CategoryBlock extends StatelessWidget {
  final InterestCategory category;
  final _InterestsPageState state;

  const _CategoryBlock({required this.category, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = state._picksIn(category).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                category.title,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
              ),
            ),
            //"2/3" — makes the per-category budget obvious at a glance
            Text(
              '$picked/${category.maxSelections}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in category.options)
              _InterestBox(
                label: option,
                selected: state.isSelected(category, option),
                //greyed out once the category is full, but still tappable to
                //deselect if it's one of the picked ones
                dimmed: state.isCategoryFull(category) &&
                    !state.isSelected(category, option),
                onTap: () => state.toggleInterest(category, option),
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
      //only the unpickable ones fade, so a full category still reads clearly
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
