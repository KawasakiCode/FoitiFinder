//Everything one user is allowed to see about another.
//
//ONE TYPE FOR BOTH SIDES. The preview of your own profile and the page you
//reach by tapping a card render the same widget, so they cannot drift apart -
//which is the whole point of a preview. Your own data arrives as a UserModel
//and is converted here; someone else's arrives from GET /users/{id}/profile.
//
//Nothing here is private: no email, no uid, no preferences, no Instagram
//handle. If a field cannot be shown to a stranger, it does not belong in this
//class - see the endpoint's comment for the same rule on the server.

import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/utils/age.dart';

class ProfilePhoto {
  final String url;
  //the caption behind this photo, never set for photo 0
  final String? story;

  const ProfilePhoto({required this.url, this.story});

  factory ProfilePhoto.fromJson(Map<String, dynamic> json) =>
      ProfilePhoto(url: json['url'] as String, story: json['story'] as String?);
}

class PublicProfile {
  final int? id;
  final String name;
  final int? age;
  final int? heightCm;
  final String? bio;
  final List<ProfilePhoto> photos;

  final String? job;
  final String? volunteering;
  final String? university;
  final String? major;
  final String? city;
  final List<String> languagesSpoken;

  final List<String> interestTags;
  final List<String> traitTags;
  //the pick-from-a-list answers, keyed by ProfileChoice.key, exactly as
  //UserModel holds them: a single answer is a list of 0 or 1
  final Map<String, List<String>> choices;

  const PublicProfile({
    required this.name,
    this.id,
    this.age,
    this.heightCm,
    this.bio,
    this.photos = const [],
    this.job,
    this.volunteering,
    this.university,
    this.major,
    this.city,
    this.languagesSpoken = const [],
    this.interestTags = const [],
    this.traitTags = const [],
    this.choices = const {},
  });

  List<String> choice(String key) => choices[key] ?? const [];

  String? get profilePictureUrl => photos.isEmpty ? null : photos.first.url;

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    List<String> list(dynamic value) =>
        value is List ? List<String>.unmodifiable(value.cast<String>()) : const [];

    //a single answer arrives as a string, a multi-answer one as a list
    List<String> answer(dynamic value) {
      if (value == null) return const [];
      if (value is String) return value.isEmpty ? const [] : [value];
      return list(value);
    }

    return PublicProfile(
      id: json['id'] as int?,
      name: json['name'] as String,
      age: json['age'] as int?,
      heightCm: json['height_cm'] as int?,
      bio: json['bio'] as String?,
      photos: [
        for (final photo in (json['photos'] as List? ?? const []))
          ProfilePhoto.fromJson(photo as Map<String, dynamic>),
      ],
      job: json['job'] as String?,
      volunteering: json['volunteering'] as String?,
      university: json['university'] as String?,
      major: json['major'] as String?,
      city: json['city'] as String?,
      languagesSpoken: list(json['languages_spoken']),
      interestTags: list(json['interest_tags']),
      traitTags: list(json['trait_tags']),
      choices: {
        for (final choice in kProfileChoices)
          choice.key: answer(json[choice.key]),
      },
    );
  }

  //Your own profile, as a stranger would see it. The photo stories are not on
  //UserModel (they live on the photo rows), so the preview passes them in.
  factory PublicProfile.fromUser(
    UserModel user, {
    Map<String, String> stories = const {},
  }) {
    return PublicProfile(
      id: user.id,
      name: user.name,
      age: ageFromBirthday(user.birthday),
      heightCm: user.heightCm,
      bio: user.bio,
      photos: [
        for (var i = 0; i < user.photoUrls.length; i++)
          ProfilePhoto(
            url: user.photoUrls[i],
            story: i == 0 ? null : stories[user.photoUrls[i]],
          ),
      ],
      job: user.job,
      volunteering: user.volunteering,
      university: user.university,
      major: user.major,
      city: user.city,
      languagesSpoken: user.languagesSpoken,
      interestTags: user.interestTags,
      traitTags: user.traitTags,
      choices: user.choices,
    );
  }
}
