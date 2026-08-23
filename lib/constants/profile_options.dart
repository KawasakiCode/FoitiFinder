//The option lists behind the simple profile categories: habits, beliefs,
//relationship intentions and identity.
//
//Every one of these is the same shape - a title and a list of choices, picked
//either one at a time or several - so they all share ONE page
//(profile_pages/choice_page.dart) rather than a dozen near-identical files.
//Adding a category is an entry in kProfileChoices, not a new screen.
//
//`key` is what gets persisted, and it is deliberately the backend column name:
//it keeps the app and the database from drifting, and makes the eventual
//PATCH /users/me body a straight map of key -> value.
//
//TODO: labels are hardcoded English like the interest catalogue. Both need to
//move to app_en.arb / app_el.arb before launch.

//How many options a category accepts.
enum ChoiceMode {
  //exactly one, tapping another swaps it (radio)
  single,
  //any number, including none (checkbox)
  multi,
}

class ProfileChoice {
  //backend column name, also the map key the profile page stores under
  final String key;
  final String title;
  //shown under the title to explain what is being asked
  final String subtitle;
  final ChoiceMode mode;
  final List<String> options;

  const ProfileChoice({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.options,
  });
}

//=========================================================================
//HABITS
//=========================================================================
const ProfileChoice kChoiceAlcohol = ProfileChoice(
  key: 'alcohol',
  title: 'Alcohol',
  subtitle: 'How often do you drink?',
  mode: ChoiceMode.single,
  options: ['Never', 'Sometimes', 'Yes'],
);

const ProfileChoice kChoiceSmoking = ProfileChoice(
  key: 'smoking',
  title: 'Smoking',
  subtitle: 'How often do you smoke?',
  mode: ChoiceMode.single,
  options: ['Never', 'Sometimes', 'Yes'],
);

//=========================================================================
//WHAT I WANT IN MY RELATIONSHIPS
//=========================================================================
const ProfileChoice kChoiceDatingIntention = ProfileChoice(
  key: 'dating_intention',
  title: 'Dating intention',
  subtitle: 'What are you looking for?',
  mode: ChoiceMode.single,
  options: [
    'Something casual',
    'A long-term relationship',
    'Still figuring it out',
  ],
);

const ProfileChoice kChoiceKids = ProfileChoice(
  key: 'kids',
  title: 'Kids',
  subtitle: 'Where do you stand on children?',
  mode: ChoiceMode.single,
  options: [
    "I'm open to kids",
    "I want kids",
    "I don't want kids",
    'Have kids',
    "Still figuring it out",
  ],
);

//=========================================================================
//BELIEFS AND VALUES
//=========================================================================
//Orthodox first: it is by far the most common answer in Greece, and burying
//it under an alphabetical list would make the common case the slowest to pick.
const ProfileChoice kChoiceReligion = ProfileChoice(
  key: 'religion',
  title: 'Religion',
  subtitle: 'Pick any that apply.',
  mode: ChoiceMode.multi,
  options: [
    'Christian',
    'Catholic',
    'Protestant',
    'Muslim',
    'Jewish',
    'Hindu',
    'Buddhist',
    'Spiritual',
    'Agnostic',
    'Atheist',
    'Taoist',
    'Bahai',
    'Jain',
    'New Age',
    'Shinto',
    'Sikh',
  ],
);

//NOTE: multi-select because the layout says "same as religion". If a single
//answer reads better, flipping mode to ChoiceMode.single is the only change
//needed here - but the backend column has to become a scalar to match.
const ProfileChoice kChoicePoliticalView = ProfileChoice(
  key: 'political_view',
  title: 'Political view',
  subtitle: 'Pick any that apply.',
  mode: ChoiceMode.multi,
  options: [
    'Anarchist',
    'Apolitical',
    'Centrist',
    'Communist',
    'Conservative',
    'Democratic',
    'Feminist',
    'Globalist',
    'Green',
    'Labour',
    'Left-Leaning',
    'Liberal',
    'Libertarian',
    'Nationalist',
    'Progressive',
    'Republican',
    'Right-Leaning',
    'Socialist'
  ],
);

const ProfileChoice kChoiceSexualOrientation = ProfileChoice(
  key: 'sexual_orientation',
  title: 'Sexual orientation',
  subtitle: 'How do you identify?',
  mode: ChoiceMode.single,
  options: [
    'Straight',
    'Gay',
    'Lesbian',
    'Bisexual',
    'Asexual'
  ],
);

const ProfileChoice kChoicePronouns = ProfileChoice(
  key: 'pronouns',
  title: 'Pronouns',
  subtitle: 'What should people call you?',
  mode: ChoiceMode.single,
  options: [
    'he/him',
    'she/her',
    'they/them'
  ],
);

//Every choice-based category, so the profile page can look one up by key.
const List<ProfileChoice> kProfileChoices = [
  kChoiceAlcohol,
  kChoiceSmoking,
  kChoiceDatingIntention,
  kChoiceKids,
  kChoiceReligion,
  kChoicePoliticalView,
  kChoiceSexualOrientation,
  kChoicePronouns,
];

//Keys for the pages that are NOT simple choice lists, so the profile page can
//route them without magic strings.
const String kEntryEducation = 'education';
const String kEntryOccupation = 'occupation';
const String kEntryLocation = 'location';
