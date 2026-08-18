//This file makes all the api calls to the python fast api server
//Each static function serves a specific purpose and calls one endpoint from the server

import 'dart:convert';
import 'package:foitifinder/models/card_data_model.dart';
import 'package:foitifinder/models/liker_model.dart';
import 'package:foitifinder/models/matches_model.dart';
import 'package:foitifinder/models/photos_model.dart';
import 'package:foitifinder/models/settings_model.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ApiService {
  /// HTTP base for the FastAPI backend. Override at compile time, e.g.
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000` (Android emulator).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Auth headers for every backend call.
  ///
  /// The backend derives WHO is calling from this Firebase ID token — a JWT
  /// signed by Google — and no longer trusts any uid we put in a path or body.
  /// That's what stops anyone from acting as anyone else just by knowing a uid.
  ///
  /// `getIdToken()` returns the cached token and refreshes it automatically once
  /// it expires (~1h), so calling this per request is both safe and cheap.
  ///
  /// NOTE: several methods below still take a `uid` argument. Those are now
  /// vestigial (identity comes from the token) and kept only to avoid churning
  /// every call site in this change — they're safe to remove in a later pass.
  static Future<Map<String, String>> _authHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  //Create new user (only runs on sign up)
  static Future<void> createUser({
    required String uid,
    required String username,
    required String? fullName,
    required String? bio,
    required int? age,
    required String? imageUrl,
    required String? gender,
    required int? minAgeRange,
    required int? maxAgeRange,
    required bool? showOutOfRange,
    required bool? isBalanced,
    required String? interests,
    required bool? hasFinishedSetUp,
    required bool? hasPhotos,
    required double? score,
  }) async {
    
    final url = Uri.parse('$baseUrl/users/');

    try {
      final response = await http.post(
        url,
        headers: await _authHeaders(),
        body: jsonEncode({
          "username": username,
          "full_name": fullName,
          "has_finished_set_up": hasFinishedSetUp,
          "bio": bio,
          "age": age,
          "profile_picture": imageUrl,
          "gender": gender,
          "min_age_range": minAgeRange,
          "max_age_range": maxAgeRange,
          "show_out_of_range": showOutOfRange,
          "is_balanced": isBalanced,
          "interests": interests,
          "has_photos": hasPhotos,
          "score": score,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        //include the server's reply: a 422 body names the exact field that
        //failed validation, which is otherwise invisible from the app
        throw Exception(
          "Failed to create user (${response.statusCode}) ${response.body}",
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  //Update user data
  static Future<void> updateUserData({
    required String uid,
    String? username,
    String? fullName,
    bool? hasFinishedSetUp,
    String? bio,
    int? age,
    String? imageUrl,
    String? gender,
    int? minAgeRange,
    int? maxAgeRange,
    bool? showOutOfRange,
    bool? isBalanced,
    String? interests,
    bool? hasPhotos
  }) async {
    final url = Uri.parse('$baseUrl/users/me');

    final Map<String, dynamic> data = {};

    if (username != null) data['username'] = username;
    if (fullName != null) data['full_name'] = fullName;
    if (hasFinishedSetUp != null) data['has_finished_set_up'] = hasFinishedSetUp;
    if (bio != null) data['bio'] = bio;
    if (age == 0) {
      data['age'] = null;
    }
    else if (age != null) {
      data['age'] = age;
    }
    if (imageUrl != null) data['profile_picture'] = imageUrl;
    if (gender != null) data['gender'] = gender;
    if (minAgeRange != null) data['min_age_range'] = minAgeRange;
    if (maxAgeRange != null) data['max_age_range'] = maxAgeRange;
    if (showOutOfRange != null) data['show_out_of_range'] = showOutOfRange;
    if (isBalanced != null) data['is_balanced'] = isBalanced;
    if (interests != null) data['interests'] = interests;
    if (hasPhotos != null) data['has_photos'] = hasPhotos;

    if(data.isEmpty)return;

    try {
      final response = await http.patch(
        url,
        headers: await _authHeaders(),
        body: jsonEncode(data),
      );
      if(response.statusCode != 200) {
        throw Exception("failed to update image in db ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //Delete user
  //no uid argument: the backend deletes whoever the verified token identifies
  static Future<void> deleteUserData() async {
    final url = Uri.parse('$baseUrl/users/me');
    try {
      final response = await http.delete(url, headers: await _authHeaders());
      if (response.statusCode == 200 || response.statusCode == 404) {
        return;
      }
      else {
        throw Exception("Failed to delete user data: ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //Get users data back
  static Future<UserModel?> getUserData(String uid) async {
    final url = Uri.parse('$baseUrl/users/me');
    try {
      final response = await http.get(url, headers: await _authHeaders());

      if(response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return UserModel.fromJson(data);
      }
      else if (response.statusCode == 404){
        return null;
      }
      else {
        throw Exception("Failed to get data ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //Update user's  settings
  static Future<void> updateUsersSettings({
    required String uid,
    bool? isDarkMode,
    bool? isLikeNotificationsOn,
    String? language,
  }) async {
    final url =  Uri.parse('$baseUrl/users/settings');

    final Map<String, dynamic> data = {};
      if (isDarkMode  != null) data['is_dark_mode'] = isDarkMode;
      if (isLikeNotificationsOn != null) data['is_like_notifications_on'] = isLikeNotificationsOn;
      if (language != null) data['language'] = language;

    if(data.isEmpty)return;

    try {
      final response =  await http.patch(
        url,
        headers: await _authHeaders(),
        body: jsonEncode(data),
      );
      if(response.statusCode != 200) {
        throw Exception("Failed to update settings in db ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //Get user's settings back
  static Future<SettingsModel> getUsersSettings(String uid) async {
    final url = Uri.parse("$baseUrl/users/settings");
    try {
      final response = await http.get(url, headers: await _authHeaders());

      if(response.statusCode == 200) {
        final Map<String, dynamic> settings = jsonDecode(response.body);
        return SettingsModel.fromJson(settings);
      }
      else {
        throw Exception("Failed to get data ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //Get multiple users to display as cards
  static Future<List<CardData>> getMultipleUsers(String uid) async {
    final url = Uri.parse("$baseUrl/users/feed");
    try {
      final response = await http.get(url, headers: await _authHeaders());

      if(response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        List<CardData> cards = body.map((dynamic item) => CardData.fromPostgresRow(item)).toList();
        return cards;
      }
      else {
        return [];
      }
    } catch (e) {
      rethrow;
    }
  }

  //Get matches aka dms
  static Future<List<MatchModel>> getMatches({
    required String uid,
  }) async {
    final url = Uri.parse("$baseUrl/matches");

    try {
      final response = await http.get(url, headers: await _authHeaders());

      if(response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => MatchModel.fromJson(item)).toList();
      }
      else  {
        throw Exception("Failed to register like ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //Get all likes
  static Future<List<LikerModel>> getLikes(String uid) async {
    final url = Uri.parse("$baseUrl/likes");

    try {
      final response = await http.get(url, headers: await _authHeaders());

      if(response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => LikerModel.fromJson(json)).toList();
      }
      else {
        throw Exception("Failed to get messages ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //Get user photos
  static Future<List<PhotosModel>> getPhotos(String uid) async {
    final url = Uri.parse("$baseUrl/photos");

    try {
      final response = await http.get(url, headers: await _authHeaders());

      if(response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PhotosModel.fromJson(json)).toList();
      }
      else {
        throw Exception("Failed to get photos ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //Upload a photo to database
  static Future<bool> uploadPhoto({
    required String uid,
    required String photoUrl,
    required int displayOrder,
  }) async {
    final url = Uri.parse("$baseUrl/photos");

    try {
      final response = await http.post(url,
      headers: await _authHeaders(),
      body: jsonEncode({
        "photo_url": photoUrl,
        "display_order": displayOrder,
      })
      );

      if(response.statusCode != 200) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  //Replace the user's photos with this exact ordered list in one call. New
  //files must already be uploaded to Firebase Storage (their URLs passed here);
  //existing photos keep their URLs. The backend reconciles rows: keeps
  //unchanged, inserts new, deletes removed — so nothing gets duplicated.
  static Future<bool> syncPhotos({
    required String uid,
    required List<String> photoUrls,
  }) async {
    final url = Uri.parse("$baseUrl/photos/sync");
    try {
      final response = await http.put(
        url,
        headers: await _authHeaders(),
        body: jsonEncode({
          "photo_urls": photoUrls,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  //Upload the photo file to firebase cloud and return the url
  static Future<String?> uploadToFirebase(File imageFile, String uid) async {
    try {
      //To ensure unique file name and path
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('users/$uid/gallery/$fileName.jpg');

      UploadTask task = ref.putFile(imageFile);
      TaskSnapshot snapshot = await task;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  //Register swipe (pass, like, super like)
  static Future<bool> registerSwipe(String uid, int otherUserId, String action) async {
    final url = Uri.parse("$baseUrl/swipes");

    try {
      final response = await http.post(url,
      headers: await _authHeaders(),
      body: jsonEncode({
        "target_id": otherUserId,
        "action": action,
      }));
      if(response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['data'] ?? false;
      }
      else {
        throw Exception("Failed to register swipe ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //Get a single user by id
  static Future<CardData> getSingleUser(int userId) async {
    final url = Uri.parse("$baseUrl/single/user/$userId");

    try {
      final response = await http.get(url, headers: await _authHeaders());

      if(response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        CardData user = CardData.fromPostgresRow(data);
        return user;
      }
      else {
        throw Exception("Failed to grab user ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }
}
