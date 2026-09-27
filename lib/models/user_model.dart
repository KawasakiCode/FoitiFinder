//user model for the user that will be sent to the database
//email and password are missing because they are on firebase and not in the database
//the database and firebase are connected through the firebase_uid to find specific users

//Age, gender, minMaxAgeRange, preferredGender are here
//and not in settings model because they affect the matching algorithm and its
//easier to grab all data needed from one model

import 'package:flutter/foundation.dart';
import 'package:foitifinder/constants/profile_options.dart';

class UserModel{
  final int? id;
  final String uid;
  //The one and only name. A dating profile has no use for a handle: nothing
  //looks anyone up and nothing is @-mentioned, so there is no second field.
  final String name;
  final String? bio;
  //the stored truth. Age is DERIVED from this (utils/age.dart) so it can
  //never go stale the way an age column does.
  final DateTime? birthday;
  //centimetres
  final int? heightCm;
  //place of residence. Prefilled from the university's city at signup
  //(constants/university_domains.dart) and editable afterwards.
  final String? city;
  //The user's photos in display order. [0] IS the profile picture - there is
  //no separate column for it any more, so the two can never disagree.
  final List<String> photoUrls;
  final String? gender;
  final int? minAgeRange;
  final int? maxAgeRange;
  //the GENDER PREFERENCE ('Men,Women'), not profile interests. Backend
  //column preferred_gender.
  final String? preferredGender;
  final bool hasFinishedSetUp;
  final bool hasPhotos;
  final double score;

  //Every pick-from-a-list answer, profile AND date preference, keyed by
  //backend column (the ProfileChoice key): 'alcohol' -> ['Never'],
  //'preferred_kids' -> ['I want kids', 'Have kids'].
  //
  //One map instead of a field each because the pages already work in exactly
  //this shape. Single-answer columns are a plain string in the database and a
  //list of 0 or 1 here, so every entry reads the same way. A missing key is
  //the same as an empty list: not answered.
  final Map<String, List<String>> choices;
  //Hobbies & interests and Traits picks, flat. Canonical English.
  final List<String> interestTags;
  final List<String> traitTags;
  //Languages spoken, canonical English, from constants/languages.dart
  final List<String> languagesSpoken;
  //Languages the other person must speak - at least one match. Empty = no
  //language filter at all.
  final List<String> preferredLanguages;
  //---- background, all free text and all optional ----
  //Where they study. DERIVED BY THE BACKEND from the verified student email at
  //signup and read-only here - the app cannot set it, which is what makes it
  //worth showing on a profile at all.
  final String? university;
  //the degree/programme, typed by the user
  final String? major;
  final bool? isCurrentlyStudying;
  final String? job;
  final String? volunteering;
  //centimetres, null = no bound on that side
  final int? minHeightPreference;
  final int? maxHeightPreference;
  final bool showOutsideResidence;

  UserModel({
    required this.uid,
    required this.name,
    required this.hasFinishedSetUp,
    required this.hasPhotos,
    required this.score,
    this.id,
    this.bio,
    this.birthday,
    this.heightCm,
    this.city,
    this.photoUrls = const [],
    this.gender, 
    this.minAgeRange,
    this.maxAgeRange,
    this.preferredGender,
    this.choices = const {},
    this.interestTags = const [],
    this.traitTags = const [],
    this.languagesSpoken = const [],
    this.preferredLanguages = const [],
    this.university,
    this.major,
    this.isCurrentlyStudying,
    this.job,
    this.volunteering,
    this.minHeightPreference,
    this.maxHeightPreference,
    this.showOutsideResidence = true,
  });

  List<String> choice(String key) => choices[key] ?? const [];

  //null when the user has no photos yet (only possible mid-signup)
  String? get profilePictureUrl => photoUrls.isEmpty ? null : photoUrls.first;

  //A copy with some fields replaced. Everything not passed is carried over, so
  //there is no field list to keep in sync by hand.
  //
  //Nullable fields take a function instead of a value, because a plain `null`
  //could not tell "leave it alone" apart from "set it to null" - and putting an
  //empty field back after a failed save needs exactly that:
  //  user.copyWith(birthday: () => null)
  UserModel copyWith({
    String? name,
    ValueGetter<String?>? bio,
    ValueGetter<DateTime?>? birthday,
    ValueGetter<int?>? heightCm,
    ValueGetter<String?>? city,
    List<String>? photoUrls,
    ValueGetter<String?>? gender,
    ValueGetter<int?>? minAgeRange,
    ValueGetter<int?>? maxAgeRange,
    ValueGetter<String?>? preferredGender,
    bool? hasFinishedSetUp,
    bool? hasPhotos,
    double? score,
    Map<String, List<String>>? choices,
    List<String>? interestTags,
    List<String>? traitTags,
    List<String>? languagesSpoken,
    List<String>? preferredLanguages,
    ValueGetter<String?>? university,
    ValueGetter<String?>? major,
    ValueGetter<bool?>? isCurrentlyStudying,
    ValueGetter<String?>? job,
    ValueGetter<String?>? volunteering,
    ValueGetter<int?>? minHeightPreference,
    ValueGetter<int?>? maxHeightPreference,
    bool? showOutsideResidence,
  }) {
    return UserModel(
      id: id,
      uid: uid,
      name: name ?? this.name,
      bio: bio != null ? bio() : this.bio,
      birthday: birthday != null ? birthday() : this.birthday,
      heightCm: heightCm != null ? heightCm() : this.heightCm,
      city: city != null ? city() : this.city,
      photoUrls: photoUrls ?? this.photoUrls,
      gender: gender != null ? gender() : this.gender,
      minAgeRange: minAgeRange != null ? minAgeRange() : this.minAgeRange,
      maxAgeRange: maxAgeRange != null ? maxAgeRange() : this.maxAgeRange,
      preferredGender:
          preferredGender != null ? preferredGender() : this.preferredGender,
      hasFinishedSetUp: hasFinishedSetUp ?? this.hasFinishedSetUp,
      hasPhotos: hasPhotos ?? this.hasPhotos,
      score: score ?? this.score,
      choices: choices ?? this.choices,
      interestTags: interestTags ?? this.interestTags,
      traitTags: traitTags ?? this.traitTags,
      languagesSpoken: languagesSpoken ?? this.languagesSpoken,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      university: university != null ? university() : this.university,
      major: major != null ? major() : this.major,
      isCurrentlyStudying: isCurrentlyStudying != null
          ? isCurrentlyStudying()
          : this.isCurrentlyStudying,
      job: job != null ? job() : this.job,
      volunteering: volunteering != null ? volunteering() : this.volunteering,
      minHeightPreference: minHeightPreference != null
          ? minHeightPreference()
          : this.minHeightPreference,
      maxHeightPreference: maxHeightPreference != null
          ? maxHeightPreference()
          : this.maxHeightPreference,
      showOutsideResidence: showOutsideResidence ?? this.showOutsideResidence,
    );
  }

  //A copy with ONE choice answer replaced
  UserModel withChoice(String key, List<String> picks) =>
      copyWith(choices: {...choices, key: List.unmodifiable(picks)});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel ( 
      uid: json['firebase_uid'] ?? (throw Exception("Critical: uid missing")),
      name: json['name'] ?? (throw Exception("Critical: name missing")),
      hasFinishedSetUp: json['has_finished_set_up'] ?? (throw Exception("Critical: finishedSetUp missing")),
      score: (json['score'] ?? 0).toDouble(),
      id: json['id'],
      bio: json['bio'],
      birthday: json['birthday'] == null
          ? null
          : DateTime.parse(json['birthday'] as String),
      heightCm: json['height_cm'],
      city: json['city'],
      photoUrls: _readList(json['photo_urls']),
      gender: json['gender'],
      minAgeRange: json['min_age_range'],
      maxAgeRange: json['max_age_range'],
      preferredGender: json['preferred_gender'],
      hasPhotos: json['has_photos'],
      choices: {
        for (final choice in _allChoices)
          choice.key: _readChoice(json[choice.key]),
      },
      interestTags: _readList(json['interest_tags']),
      traitTags: _readList(json['trait_tags']),
      languagesSpoken: _readList(json['languages_spoken']),
      preferredLanguages: _readList(json['preferred_languages']),
      university: json['university'],
      major: json['major'],
      isCurrentlyStudying: json['is_currently_studying'],
      job: json['job'],
      volunteering: json['volunteering'],
      minHeightPreference: json['min_height_preference'],
      maxHeightPreference: json['max_height_preference'],
      //missing (an older cache) reads as the column default
      showOutsideResidence: json['show_outside_residence'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firebase_uid': uid,
      'name': name,
      'has_finished_set_up': hasFinishedSetUp,
      'score' : score,
      'id': id,
      'bio': bio,
      //date only, no time - matches the DATE column and survives a round
      //trip through SharedPreferences unchanged
      'birthday': birthday?.toIso8601String().split('T').first,
      'height_cm': heightCm,
      'city': city,
      'photo_urls': photoUrls,
      'gender': gender,
      'min_age_range': minAgeRange,
      'max_age_range': maxAgeRange,
      'preferred_gender': preferredGender,
      'has_photos': hasPhotos,
      //the same shape the backend sends, so fromJson reads the cache back
      for (final choice in _allChoices)
        choice.key: choiceToJson(choice, this.choice(choice.key)),
      'interest_tags': interestTags,
      'trait_tags': traitTags,
      'languages_spoken': languagesSpoken,
      'preferred_languages': preferredLanguages,
      'university': university,
      'major': major,
      'is_currently_studying': isCurrentlyStudying,
      'job': job,
      'volunteering': volunteering,
      'min_height_preference': minHeightPreference,
      'max_height_preference': maxHeightPreference,
      'show_outside_residence': showOutsideResidence,
    };
  }
}

const List<ProfileChoice> _allChoices = [
  ...kProfileChoices,
  ...kDatePreferenceChoices,
];

//A single-answer column arrives as a string or null, a multi-answer one as a
//list. Both become a list here.
List<String> _readChoice(dynamic value) {
  if (value == null) return const [];
  if (value is String) return value.isEmpty ? const [] : [value];
  return _readList(value);
}

List<String> _readList(dynamic value) =>
    value is List ? List.unmodifiable(value.cast<String>()) : const [];

//What a choice answer looks like in a PATCH body. Single-answer columns take
//the string, and '' to clear (null would be dropped as "unchanged" and the
//backend turns '' into NULL). Multi-answer columns take the list.
Object choiceToJson(ProfileChoice choice, List<String> picks) {
  if (choice.mode == ChoiceMode.multi) return picks;
  return picks.isEmpty ? '' : picks.first;
}
