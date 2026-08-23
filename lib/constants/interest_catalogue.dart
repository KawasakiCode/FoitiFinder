//The interest catalogue: the data behind the Hobbies & interests / Traits /
//Bio / Q&A's categories reachable from the profile page.
//
//Three levels deep:
//  group    -> the 4 broad blocks, one per row on the profile page
//  section  -> the subcategory inside a group (Activities, Music, MBTI, ...)
//  option   -> the actual tappable box
//
//Budgets stack: a pick has to clear BOTH its section's own cap and its group's
//shared budget.
//  * "Hobbies & interests" and "Traits" each have ONE shared budget of 10 spread
//    across their sections - spending a pick on Music takes one away from Sports.
//  * inside Traits, two sections additionally cap themselves at 1 (star sign and
//    MBTI), because those are single-answer facts.
//Picking 0 anywhere is fine.
//
//DECIDED, not a bug: star sign and MBTI are paid for out of the same 10 as the
//rest of Traits, so spending all 10 on personality traits leaves no room to set
//them. Only the FIRST pick in those sections costs a slot - swapping one star
//sign for another is free even at 10/10.
//
//NAMING WARNING: UserModel.interests already exists and means something else -
//it is the comma separated gender preference ("Men"/"Women"/"Everyone") read by
//interests_to_genders() in the backend. These tags are a separate concept and
//must NOT be persisted into that column. Pick a distinct name (e.g.
//interest_tags) when the backend column is added.
//
//TODO: these labels are hardcoded English - the app ships Greek too, so they
//need to move to app_en.arb / app_el.arb before this goes live.

//A subcategory: a title and the boxes under it.
class InterestSection {
  final String title;
  final List<String> options;
  //this section's OWN cap. null means it has none and only the group's shared
  //budget applies. When both exist the tighter one wins.
  //A section capped at 1 behaves like a radio: tapping a different box swaps the
  //pick instead of being refused, which is what you want for MBTI and star sign.
  final int? maxSelections;

  const InterestSection(this.title, this.options, {this.maxSelections});
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
  //2. TRAITS — 4 sections sharing a budget of 10. Star sign and MBTI cap
  //themselves at 1 on top of that, since you only get one of each.
  //Gender and age range are deliberately absent: they already live in settings.
  //=========================================================================
  InterestGroup(
    'Traits',
    sharedMax: 10,
    sections: [
      InterestSection('Personality traits', [
        'Introvert',
        'Adventurous',
        'Ambitious',
        'Ambivert',
        'Calm',
        'Caring',
        'Chaotic',
        'Competition seeker',
        'Creative',
        'Curious',
        'Deep thinker',
        'Dreamer',
        'Empathetic',
        'Energetic',
        'Extravert',
        'Flexible',
        'Generous',
        'Go-getter',
        'Honest',
        'Kind',
        'Listener',
        'Open-minded',
        'Optimistic',
        'Organized',
        'Outgoing',
        'Passionate',
        'Patient',
        'Perfectionist',
        'Playful',
        'Positive',
        'Romantic',
        'Spontaneous',
        'Supportive',
        'Witty',
      ]),
      InterestSection('Star sign', [
        'Aries',
        'Taurus',
        'Gemini',
        'Cancer',
        'Leo',
        'Virgo',
        'Libra',
        'Scorpio',
        'Sagittarius',
        'Capricorn',
        'Aquarius',
        'Pisces',
      ], maxSelections: 1),
      InterestSection('Personality type (MBTI)', [
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
      InterestSection('Lifestyle', [
        'Early bird',
        'Activist',
        'Animal lover',
        'Bohemian',
        'Corporate',
        'Cozy at home',
        'Digital nomad',
        'Family orientated',
        'Foodie',
        'Health',
        'Maximalist',
        'Minimalist',
        'Music lover',
        'Night owl',
        'Pet free',
        'Sober',
        'Spiritual',
        'Sportive',
        'Student association',
        'Sustainable',
        'Thrill seeker',
        'Wanderlust',
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
];

//Group titles, used to route each profile row to the right page. Kept as
//constants so a typo is a compile error instead of a silently missing group.
const String kGroupHobbies = 'Hobbies & interests';
const String kGroupTraits = 'Traits';
const String kGroupBio = 'Bio';
const String kGroupQA = "Q&A's";

//Look a group up by title. Throws rather than returning null: every caller
//passes one of the constants above, so a miss means the catalogue and the
//routing have drifted apart and we want to know immediately.
InterestGroup interestGroupByTitle(String title) =>
    kInterestGroups.firstWhere((g) => g.title == title);
