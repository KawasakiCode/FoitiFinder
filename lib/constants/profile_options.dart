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

//Answer lists shared by a profile question and the date preference that
//filters on it. One list, so the two can never offer different answers and a
//preference always compares against values people actually pick.
const List<String> kFrequencyOptions = ['Never', 'Sometimes', 'Yes'];

const List<String> kDatingIntentionOptions = [
  'Something casual',
  'Something serious',
  'Still figuring it out',
];

const List<String> kKidsOptions = [
  "I'm open to kids",
  "I want kids",
  "I don't want kids",
  'Have kids',
  "Still figuring it out",
];

//=========================================================================
//HABITS
//=========================================================================
const ProfileChoice kChoiceAlcohol = ProfileChoice(
  key: 'alcohol',
  title: 'Alcohol',
  subtitle: 'How often do you drink?',
  mode: ChoiceMode.single,
  options: kFrequencyOptions,
);

const ProfileChoice kChoiceSmoking = ProfileChoice(
  key: 'smoking',
  title: 'Smoking',
  subtitle: 'How often do you smoke?',
  mode: ChoiceMode.single,
  options: kFrequencyOptions,
);

//=========================================================================
//WHAT I WANT IN MY RELATIONSHIPS
//=========================================================================
const ProfileChoice kChoiceDatingIntention = ProfileChoice(
  key: 'dating_intention',
  title: 'Dating intention',
  subtitle: 'What are you looking for?',
  mode: ChoiceMode.single,
  options: kDatingIntentionOptions,
);

const ProfileChoice kChoiceKids = ProfileChoice(
  key: 'kids',
  title: 'Kids',
  subtitle: 'Where do you stand on children?',
  mode: ChoiceMode.single,
  options: kKidsOptions,
);

//=========================================================================
//DATE PREFERENCES - what the user wants the OTHER person to have
//=========================================================================
//Same titles and answers as the profile questions above, asked as "what do
//you want?" instead of "what are you?".
//
//MULTI-select, unlike the profile side: someone can be fine with a partner who
//drinks "Never" OR "Sometimes". Picking nothing means no preference at all.
//
//The keys are the backend columns (text[] arrays).
const ProfileChoice kPrefAlcohol = ProfileChoice(
  key: 'preferred_alcohol',
  title: 'Alcohol',
  subtitle: 'What do you want?',
  mode: ChoiceMode.multi,
  options: kFrequencyOptions,
);

const ProfileChoice kPrefSmoking = ProfileChoice(
  key: 'preferred_smoking',
  title: 'Smoking',
  subtitle: 'What do you want?',
  mode: ChoiceMode.multi,
  options: kFrequencyOptions,
);

const ProfileChoice kPrefDatingIntention = ProfileChoice(
  key: 'preferred_dating_intention',
  title: 'Dating intention',
  subtitle: 'What do you want?',
  mode: ChoiceMode.multi,
  options: kDatingIntentionOptions,
);

const ProfileChoice kPrefKids = ProfileChoice(
  key: 'preferred_kids',
  title: 'Kids',
  subtitle: 'What do you want?',
  mode: ChoiceMode.multi,
  options: kKidsOptions,
);

//=========================================================================
//BELIEFS AND VALUES
//=========================================================================
//ONE ANSWER, not several. Multi-select let someone be Christian AND Atheist,
//which is not nuance, it is a contradiction - and on a profile it read as two
//pills arguing with each other. The genuinely in-between answers are already
//in the list ('Spiritual', 'Agnostic'), so the honest question is "which one
//would you tell someone", and that has exactly one answer.
//
//Orthodox first: it is by far the most common answer in Greece, and burying
//it under an alphabetical list would make the common case the slowest to pick.
const ProfileChoice kChoiceReligion = ProfileChoice(
  key: 'religion',
  title: 'Religion',
  subtitle: 'Pick the one that fits you best.',
  mode: ChoiceMode.single,
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

//Single for the same reason as religion: 'Liberal' and 'Conservative' at once
//says nothing at all. Both columns are plain text now, not arrays.
const ProfileChoice kChoicePoliticalView = ProfileChoice(
  key: 'political_view',
  title: 'Political view',
  subtitle: 'Pick the one that fits you best.',
  mode: ChoiceMode.single,
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

//The date preference choices, same idea as kProfileChoices.
const List<ProfileChoice> kDatePreferenceChoices = [
  kPrefAlcohol,
  kPrefSmoking,
  kPrefDatingIntention,
  kPrefKids,
];

//Keys for the pages that are NOT simple choice lists, so the profile page can
//route them without magic strings.
const String kEntryEducation = 'education';
const String kEntryOccupation = 'occupation';
const String kEntryLocation = 'location';
