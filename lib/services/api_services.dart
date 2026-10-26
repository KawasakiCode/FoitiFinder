//This file makes all the api calls to the python fast api server
//Each static function serves a specific purpose and calls one endpoint from the server

import 'dart:convert';
import 'package:foitifinder/models/card_data_model.dart';
import 'package:foitifinder/models/liker_model.dart';
import 'package:foitifinder/models/matches_model.dart';
import 'package:foitifinder/models/match_models.dart';
import 'package:foitifinder/models/notification_model.dart';
import 'package:foitifinder/models/photos_model.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/models/settings_model.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

//WHAT WENT WRONG, not just that something did.
//
//A plain Exception("failed") cannot be acted on: a 422 means the server has
//refused the request and will refuse it again, while a 503 means come back
//later. SwipeQueue needs that difference to decide whether retrying is worth
//anything - see _isRetryable there.
class ApiException implements Exception {
  final int statusCode;
  final String body;

  const ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}

class ApiService {
  /// HTTP base for the FastAPI backend. Override at compile time, e.g.
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000` (Android emulator).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// HOW LONG ANY REQUEST MAY HANG BEFORE IT COUNTS AS FAILED.
  ///
  /// Without one, a socket that is open but silent never returns - and that
  /// is not a hypothetical: the deck, the likes page and the notification
  /// list all show a spinner while they wait, with no error and no retry
  /// button, so a backend that stops answering mid-session leaves a screen
  /// that spins forever. A thrown TimeoutException at least reaches a catch.
  ///
  /// 30s rather than something snappier because the backend sleeps when idle
  /// and a cold start costs most of a minute; anything shorter turns the
  /// first request after a quiet hour into a guaranteed failure. The swipe
  /// deliberately uses a much shorter one - see recordSwipe.
  static const Duration kRequestTimeout = Duration(seconds: 30);

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
    required String name,
    required String? bio,
    required DateTime? birthday,
    required int? heightCm,
    required String? city,
    required String? gender,
    required int? minAgeRange,
    required int? maxAgeRange,
    required String? preferredGender,
    required bool? hasFinishedSetUp,
    required bool? hasPhotos,
  }) async {
    
    final url = Uri.parse('$baseUrl/users/');

    try {
      final response = await http.post(
        url,
        headers: await _authHeaders(),
        body: jsonEncode({
          "name": name,
          "has_finished_set_up": hasFinishedSetUp,
          "bio": bio,
          "birthday": birthday?.toIso8601String().split('T').first,
          "height_cm": heightCm,
          "city": city,
          "gender": gender,
          "min_age_range": minAgeRange,
          "max_age_range": maxAgeRange,
          "preferred_gender": preferredGender,
          "has_photos": hasPhotos,
        }),
      ).timeout(kRequestTimeout);

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
    String? name,
    bool? hasFinishedSetUp,
    String? bio,
    DateTime? birthday,
    int? heightCm,
    String? city,
    String? gender,
    int? minAgeRange,
    int? maxAgeRange,
    String? preferredGender,
    bool? hasPhotos
  }) async {
    final Map<String, dynamic> data = {};

    if (name != null) data['name'] = name;
    if (hasFinishedSetUp != null) data['has_finished_set_up'] = hasFinishedSetUp;
    if (bio != null) data['bio'] = bio;
    if (birthday != null) {
      data['birthday'] = birthday.toIso8601String().split('T').first;
    }
    if (heightCm != null) data['height_cm'] = heightCm;
    //'' is how the caller clears a city - it must be SENT, not skipped like a
    //null would be. The backend turns an empty string back into NULL.
    if (city != null) data['city'] = city;
    if (gender != null) data['gender'] = gender;
    if (minAgeRange != null) data['min_age_range'] = minAgeRange;
    if (maxAgeRange != null) data['max_age_range'] = maxAgeRange;
    if (preferredGender != null) data['preferred_gender'] = preferredGender;
    if (hasPhotos != null) data['has_photos'] = hasPhotos;

    await patchUser(data);
  }

  //PATCH /users/me with exactly these columns and nothing else.
  //
  //Keys are backend column names. Unlike updateUserData, a null value IS sent,
  //which is how a nullable column is cleared (e.g. min_height_preference back
  //to "no limit"). Columns left out of the map are not touched.
  static Future<void> patchUser(Map<String, dynamic> fields) async {
    if (fields.isEmpty) return;

    final response = await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: await _authHeaders(),
      body: jsonEncode(fields),
    ).timeout(kRequestTimeout);
    if (response.statusCode != 200) {
      throw Exception("Failed to update user: ${response.body}");
    }
  }

  //Delete user
  //no uid argument: the backend deletes whoever the verified token identifies
  static Future<void> deleteUserData() async {
    final url = Uri.parse('$baseUrl/users/me');
    try {
      final response = await http.delete(url, headers: await _authHeaders()).timeout(kRequestTimeout);
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
      final response = await http.get(url, headers: await _authHeaders()).timeout(kRequestTimeout);

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
      ).timeout(kRequestTimeout);
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
      final response = await http.get(url, headers: await _authHeaders()).timeout(kRequestTimeout);

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
      final response = await http.get(url, headers: await _authHeaders()).timeout(kRequestTimeout);

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
  /// How many super likes are left this week.
  ///
  /// ASKED BEFORE ONE CAN BE SPENT. The deck animates a card away and
  /// registers the swipe afterwards, so a refusal from the server arrives
  /// when the card is already gone - the user watches a super like leave and
  /// is then told it never happened. Knowing the count lets the gesture say
  /// no first; the server check stays as the backstop.
  static Future<int> getSuperLikesLeft() async {
    final response = await http.get(
      Uri.parse("$baseUrl/swipes/super-likes"),
      headers: await _authHeaders(),
    ).timeout(kRequestTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['left'] as int;
    }
    throw ApiException(response.statusCode, response.body);
  }

  static Future<List<MatchModel>> getMatches({
    required String uid,
  }) async {
    final url = Uri.parse("$baseUrl/matches");

    try {
      final response = await http.get(url, headers: await _authHeaders()).timeout(kRequestTimeout);

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
      final response = await http.get(url, headers: await _authHeaders()).timeout(kRequestTimeout);

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
      final response = await http.get(url, headers: await _authHeaders()).timeout(kRequestTimeout);

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
      ).timeout(kRequestTimeout);

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
      ).timeout(kRequestTimeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  //Set or clear the story attached to one photo.
  //
  //Deliberately NOT part of syncPhotos: writing a caption should not require
  //re-uploading and re-ordering the whole photo set. Pass null or an empty
  //string to remove the story.
  static Future<bool> updatePhotoStory({
    required String photoUrl,
    required String? story,
  }) async {
    final url = Uri.parse("$baseUrl/photos/story");
    try {
      final response = await http.put(
        url,
        headers: await _authHeaders(),
        body: jsonEncode({
          "photo_url": photoUrl,
          "story": story,
        }),
      ).timeout(kRequestTimeout);
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
  //CALL THIS THROUGH SwipeQueue, not directly: a swipe that throws here is a
  //match that never happens, and the queue is what stops that being silent.
  static Future<SwipeResult> registerSwipe(String uid, int otherUserId, String action) async {
    final url = Uri.parse("$baseUrl/swipes");

    try {
      final response = await http.post(url,
      headers: await _authHeaders(),
      body: jsonEncode({
        "target_id": otherUserId,
        "action": action,
      }),
      //WITHOUT THIS A HUNG SOCKET NEVER FAILS, so the retry never runs and
      //the swipe is lost to a request that is still politely waiting.
      ).timeout(const Duration(seconds: 12));
      if(response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return SwipeResult(
          isMatch: data['data'] ?? false,
          //absent from an older backend: the caller then knows it is a match
          //but cannot open the match page for it
          matchId: data['match_id'],
        );
      }
      else {
        //typed, so the queue can tell "come back later" from "no"
        throw ApiException(response.statusCode, response.body);
      }
    } catch (e) {
      rethrow;
    }
  }

  //Say yes to a match.
  //
  //The handle comes back ONLY when the other side had already said yes - the
  //server decides that, not the app, and a null handle with revealed: false
  //is the normal answer for whoever confirms first.
  static Future<MatchConfirmation> confirmMatch(int matchId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/matches/$matchId/confirm"),
      headers: await _authHeaders(),
    ).timeout(kRequestTimeout);
    if (response.statusCode != 200) {
      throw Exception("Failed to confirm match ${response.body}");
    }
    final Map<String, dynamic> data = jsonDecode(response.body);
    return MatchConfirmation(
      revealed: data['revealed'] ?? false,
      otherName: data['name'] ?? '',
      instagramHandle: data['instagram_handle'],
    );
  }

  //The bell's list, newest first.
  static Future<List<AppNotification>> getNotifications() async {
    final response = await http.get(
      Uri.parse("$baseUrl/notifications"),
      headers: await _authHeaders(),
    ).timeout(kRequestTimeout);
    if (response.statusCode != 200) {
      throw Exception("Failed to load notifications ${response.body}");
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data
        .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  //Mark one as read. Idempotent on the server, so a retry is free.
  static Future<void> markNotificationRead(int id) async {
    final response = await http.post(
      Uri.parse("$baseUrl/notifications/$id/read"),
      headers: await _authHeaders(),
    ).timeout(kRequestTimeout);
    if (response.statusCode != 200) {
      throw Exception("Failed to mark notification read ${response.body}");
    }
  }

  //Change your mind: the match is deleted and the like becomes a pass.
  static Future<void> declineMatch(int matchId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/matches/$matchId/decline"),
      headers: await _authHeaders(),
    ).timeout(kRequestTimeout);
    if (response.statusCode != 200) {
      throw Exception("Failed to decline match ${response.body}");
    }
  }

  //The oldest build the backend will still talk to, or null if it would not
  //say.
  //
  //NULL ON EVERY FAILURE, AND THAT IS THE WHOLE CONTRACT. The caller blocks
  //the app with this answer, so the one thing it must never do is guess high:
  //a timeout, a 500, a cold start or a response from some future backend that
  //does not look like a number all mean "carry on". Locking people out of a
  //working app because a request failed is strictly worse than letting an old
  //build run a while longer.
  //
  //NO AUTH HEADER. The endpoint wants none, and a build old enough to be
  //refused may be old enough to get signing in wrong - the wall has to work
  //before anybody logs in.
  static Future<int?> minimumBuild() async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/app/minimum-build"))
          .timeout(kRequestTimeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      //Android only for now, and an unknown platform answers null rather than
      //falling back to somebody else's number
      final value = data is Map ? data['android'] : null;
      return value is int ? value : null;
    } catch (_) {
      return null;
    }
  }

  //Take a finished match off your own list, and only yours.
  //
  //THE OTHER PERSON KEEPS THEIRS and is told nothing - see the endpoint. 409
  //means the match is not finished, which is decline's job instead; the UI
  //only offers this in the revealed section, so a 409 here is a stale page.
  static Future<void> removeMatch(int matchId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/matches/$matchId"),
      headers: await _authHeaders(),
    ).timeout(kRequestTimeout);
    if (response.statusCode != 200) {
      throw Exception("Failed to remove match ${response.body}");
    }
  }

  //Get a single user by id
  //The full profile of another user, for the page behind a swipe card.
  //Everything a stranger may see and nothing else - the endpoint decides that,
  //not this call.
  static Future<PublicProfile> getUserProfile(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/profile'),
      headers: await _authHeaders(),
    ).timeout(kRequestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to load profile: ${response.body}');
    }
    return PublicProfile.fromJson(jsonDecode(response.body));
  }

  static Future<CardData> getSingleUser(int userId) async {
    final url = Uri.parse("$baseUrl/single/user/$userId");

    try {
      final response = await http.get(url, headers: await _authHeaders()).timeout(kRequestTimeout);

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
