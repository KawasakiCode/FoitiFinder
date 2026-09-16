//user model for the user that will be sent to the database
//email and password are missing because they are on firebase and not in the database
//the database and firebase are connected through the firebase_token (uid) to find specific users

//Age, gender, minMaxAgeRange, preferredGender are here
//and not in settings model because they affect the matching algorithm and its
//easier to grab all data needed from one model

import 'package:flutter/foundation.dart';

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
  final String? imageUrl;
  final String? gender;
  final int? minAgeRange;
  final int? maxAgeRange;
  //the GENDER PREFERENCE ('Men,Women'), not profile interests. Backend
  //column preferred_gender.
  final String? preferredGender;
  final bool hasFinishedSetUp;
  final bool hasPhotos;
  final double score;

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
    this.imageUrl,
    this.gender, 
    this.minAgeRange,
    this.maxAgeRange,
    this.preferredGender,
  });

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
    ValueGetter<String?>? imageUrl,
    ValueGetter<String?>? gender,
    ValueGetter<int?>? minAgeRange,
    ValueGetter<int?>? maxAgeRange,
    ValueGetter<String?>? preferredGender,
    bool? hasFinishedSetUp,
    bool? hasPhotos,
    double? score,
  }) {
    return UserModel(
      id: id,
      uid: uid,
      name: name ?? this.name,
      bio: bio != null ? bio() : this.bio,
      birthday: birthday != null ? birthday() : this.birthday,
      heightCm: heightCm != null ? heightCm() : this.heightCm,
      city: city != null ? city() : this.city,
      imageUrl: imageUrl != null ? imageUrl() : this.imageUrl,
      gender: gender != null ? gender() : this.gender,
      minAgeRange: minAgeRange != null ? minAgeRange() : this.minAgeRange,
      maxAgeRange: maxAgeRange != null ? maxAgeRange() : this.maxAgeRange,
      preferredGender:
          preferredGender != null ? preferredGender() : this.preferredGender,
      hasFinishedSetUp: hasFinishedSetUp ?? this.hasFinishedSetUp,
      hasPhotos: hasPhotos ?? this.hasPhotos,
      score: score ?? this.score,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel ( 
      uid: json['firebase_token'] ?? (throw Exception("Critical: uid missing")),
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
      imageUrl: json['profile_picture'],
      gender: json['gender'],
      minAgeRange: json['min_age_range'],
      maxAgeRange: json['max_age_range'],
      preferredGender: json['preferred_gender'],
      hasPhotos: json['has_photos'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firebase_token': uid,
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
      'profile_picture': imageUrl,
      'gender': gender,
      'min_age_range': minAgeRange,
      'max_age_range': maxAgeRange,
      'preferred_gender': preferredGender,
      'has_photos': hasPhotos,
    };
  }
}