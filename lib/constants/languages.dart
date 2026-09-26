//The languages a user can say they speak.
//
//A SHORT, DELIBERATE LIST, not every language on earth. This is a filter -
//"only show me people I can actually talk to" - so what matters is coverage of
//the people who will use the app, not completeness. A 200-entry list would be
//a scrolling chore where 13 is two taps.
//
//Why these:
//  * Greek and English first: the two everyone here has, and the reason the
//    filter is usually satisfied at all.
//  * German, French, Italian, Spanish: by far the most studied foreign
//    languages in Greek schools.
//  * Albanian, Russian, Bulgarian, Romanian, Ukrainian: the largest immigrant
//    and repatriate communities in Greece, so a real number of students speak
//    one at home.
//  * Turkish: the Muslim minority of Thrace, i.e. a chunk of Komotini and
//    Xanthi - which is Democritus University's student body.
//  * Greek Sign Language: deaf and hard-of-hearing students, and the hearing
//    people who sign. Leaving it out would exclude exactly the group for whom
//    a shared language matters most.
//
//CANONICAL ENGLISH, like every other catalogue: the strings below are what
//lands in users.languages_spoken, and l10n/catalogue_labels.dart translates
//them for display. See interest_catalogue.dart for the reasoning.
const List<String> kLanguages = [
  'Greek',
  'English',
  'Albanian',
  'Bulgarian',
  'French',
  'German',
  'Italian',
  'Romanian',
  'Russian',
  'Spanish',
  'Turkish',
  'Ukrainian',
  //last on purpose: it is the one entry that is not a spoken language, so it
  //reads as its own category rather than as an odd item mid-list
  'Greek Sign Language',
];
