//The prefectures (nomoi) of Greece - the unit the app uses for where
//somebody lives.
//
//WHY THIS GRANULARITY: place of residence has to be filterable, and without
//coordinates a radius filter is impossible - there is no way to answer "is
//Kalamaria within 20km of Pavlou Mela" from names alone. So the unit has to
//be coarse enough that an EXACT MATCH is a useful filter, and a prefecture is
//that: everyone in the Thessaloniki urban area picks Thessaloniki.
//
//These are the 51 nomoi with Attica split into its four prefectures (Athens,
//Piraeus, East Attica, West Attica), because a single 'Attica' entry would
//swallow a third of the country. Mount Athos is excluded: it is a monastic
//community, not somewhere a user of this app lives.
//
//ENGLISH IS CANONICAL. These strings are what reaches the database, exactly
//like the interest catalogue - see l10n/catalogue_labels.dart. The Greek
//labels live in the arb files and are applied at render only.
const List<String> kGreekPrefectures = [
  'Achaea',
  'Aetolia-Acarnania',
  'Arcadia',
  'Argolis',
  'Arta',
  'Athens',
  'Boeotia',
  'Cephalonia',
  'Chalkidiki',
  'Chania',
  'Chios',
  'Corfu',
  'Corinthia',
  'Cyclades',
  'Dodecanese',
  'Drama',
  'East Attica',
  'Elis',
  'Euboea',
  'Evros',
  'Evrytania',
  'Florina',
  'Grevena',
  'Heraklion',
  'Imathia',
  'Ioannina',
  'Karditsa',
  'Kastoria',
  'Kavala',
  'Kilkis',
  'Kozani',
  'Laconia',
  'Larissa',
  'Lasithi',
  'Lefkada',
  'Lesbos',
  'Magnesia',
  'Messenia',
  'Pella',
  'Phocis',
  'Phthiotis',
  'Pieria',
  'Piraeus',
  'Preveza',
  'Rethymno',
  'Rhodope',
  'Samos',
  'Serres',
  'Thesprotia',
  'Thessaloniki',
  'Trikala',
  'West Attica',
  'Xanthi',
  'Zakynthos',
];
