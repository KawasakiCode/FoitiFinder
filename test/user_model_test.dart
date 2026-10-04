//The profile answers take different shapes in the database (a string for a
//single answer, text[] for several, a flat tag list per group) and one shape
//in the app. These pin the conversions both ways.

import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/constants/interest_catalogue.dart';
import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/models/user_model.dart';

void main() {
  final backendJson = <String, dynamic>{
    'firebase_uid': 'uid',
    'name': 'Maria',
    'has_finished_set_up': true,
    'has_photos': true,
    'alcohol': 'Sometimes',
    'smoking': null,
    'religion': 'Christian',
    'preferred_kids': ['I want kids'],
    'interest_tags': ['Jazz', 'Hiking'],
    'trait_tags': ['Leo'],
    'min_height_preference': 160,
    'max_height_preference': null,
    'show_outside_residence': false,
  };

  test('single answers become lists of 0 or 1', () {
    final user = UserModel.fromJson(backendJson);
    expect(user.choice('alcohol'), ['Sometimes']);
    expect(user.choice('smoking'), isEmpty);
    expect(user.choice('religion'), ['Christian']);
    expect(user.choice('preferred_kids'), ['I want kids']);
  });

  test('a legacy list answer collapses to its first pick', () {
    //religion and political_view were text[] while the picker allowed several,
    //which let someone be Christian AND Atheist. Both are single answers now,
    //and the migration keeps the first one (USING religion[1]) - so a cache
    //written by the old build must land on the same value, not throw.
    final user = UserModel.fromJson({
      ...backendJson,
      'religion': ['Christian', 'Spiritual'],
      'political_view': ['Liberal', 'Conservative'],
    });
    expect(user.choice('religion'), ['Christian']);
    expect(user.choice('political_view'), ['Liberal']);
  });

  test('the cache round trip keeps every new field', () {
    final user = UserModel.fromJson(backendJson);
    final again = UserModel.fromJson(user.toMap());
    expect(again.choices, user.choices);
    expect(again.interestTags, user.interestTags);
    expect(again.traitTags, user.traitTags);
    expect(again.minHeightPreference, 160);
    expect(again.maxHeightPreference, isNull);
    expect(again.showOutsideResidence, isFalse);
  });

  test('photo 0 is the profile picture', () {
    final user = UserModel.fromJson({
      ...backendJson,
      'photo_urls': ['https://a/0.jpg', 'https://a/1.jpg'],
    });
    expect(user.profilePictureUrl, 'https://a/0.jpg');
    expect(UserModel.fromJson(user.toMap()).photoUrls, user.photoUrls);
    expect(UserModel.fromJson(backendJson).profilePictureUrl, isNull);
  });

  test('an older cache without the new fields still parses', () {
    final user = UserModel.fromJson({
      'firebase_uid': 'uid',
      'name': 'Maria',
      'has_finished_set_up': true,
      'has_photos': true,
    });
    expect(user.choices.values.every((l) => l.isEmpty), isTrue);
    expect(user.showOutsideResidence, isTrue);
  });

  test('PATCH body: single answer is a string, cleared is empty string', () {
    expect(choiceToJson(kChoiceAlcohol, ['Never']), 'Never');
    expect(choiceToJson(kChoiceAlcohol, []), '');
    expect(choiceToJson(kPrefAlcohol, ['Never', 'Sometimes']),
        ['Never', 'Sometimes']);
  });

  test('flat tags map to sections and back', () {
    final group = interestGroupByTitle(kGroupHobbies);
    final selections = selectionsFromTags(group, ['Jazz', 'Hiking', 'Gone']);
    expect(selections, {
      'Activities': ['Hiking'],
      'Music': ['Jazz'],
    });
    //section order, and the tag no longer in the catalogue is dropped
    expect(tagsFromSelections(group, selections), ['Hiking', 'Jazz']);
  });
}
