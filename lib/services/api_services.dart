import 'dart:convert';
import 'package:foitifinder/models/card_data_model.dart';
import 'package:foitifinder/models/liker_model.dart';
import 'package:foitifinder/models/matches_model.dart';
import 'package:foitifinder/models/message_model.dart';
import 'package:foitifinder/models/photos_model.dart';
import 'package:foitifinder/models/settings_model.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ApiService {
  //test for emulator
  // static const String baseUrl = "http://10.0.2.2:8000"; 
  //test for real phone
  static const String baseUrl = "http://127.0.0.1:8000"; 

  //create new user (only runs on sign up)
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
  }) async {
    
    final url = Uri.parse('$baseUrl/users/');

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json", 
        },
        body: jsonEncode({
          "firebase_token": uid,
          "username": username,
          "full_name": fullName,
          "has_finished_set_up": hasFinishedSetUp,
          "bio": bio,
          "age": age,
          "image_url": imageUrl,
          "gender": gender,
          "min_age_range": minAgeRange,
          "max_age_range": maxAgeRange,
          "show_out_of_range": showOutOfRange,
          "is_balanced": isBalanced,
          "interests": interests,
          "has_photos": hasPhotos,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Failed to create user");
      }
    } catch (e) {
      rethrow;
    }
  }

  //update user data
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
  }) async {
    final url = Uri.parse('$baseUrl/users/$uid');

    final Map<String, dynamic> data = {};

    if (username != null) data['username'] = username;
    if (fullName != null) data['full_name'] = fullName;
    if (hasFinishedSetUp != null) data['has_finished_set_up'] = hasFinishedSetUp;
    if (bio != null) data['bio'] = bio;
    if (age != null) data['age'] = age;
    if (imageUrl != null) data['profile_picture'] = imageUrl;
    if (gender != null) data['gender'] = gender;
    if (minAgeRange != null) data['min_age_range'] = minAgeRange;
    if (maxAgeRange != null) data['max_age_range'] = maxAgeRange;
    if (showOutOfRange != null) data['show_out_of_range'] = showOutOfRange;
    if (isBalanced != null) data['is_balanced'] = isBalanced;
    if (interests != null) data['interests'] = interests;

    if(data.isEmpty)return;

    try {
      final response = await http.patch(  
        url,
        headers: {"Content-type": "application/json"},
        body: jsonEncode(data),
      );
      if(response.statusCode != 200) {
        throw Exception("failed to update image in db ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //get users data back
  static Future<UserModel?> getUserData(String uid) async {
    final url = Uri.parse('$baseUrl/users/$uid');
    try {
      final response = await http.get(url);

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

  //update user's  settings
  static Future<void> updateUsersSettings({
    required String uid,
    bool? isDarkMode,
    bool? isNotificationsOn,
    String? language,
  }) async {
    final url =  Uri.parse('$baseUrl/users/settings/$uid');

    final Map<String, dynamic> data = {};
      if (isDarkMode  != null) data['is_dark_mode'] = isDarkMode;
      if (isNotificationsOn != null) data['is_notifications_on'] = isNotificationsOn;
      if (language != null) data['language'] = language;

    if(data.isEmpty)return;

    try {
      final response =  await http.patch( 
        url,
        headers: {"Content-type": "application/json"},
        body: jsonEncode(data),
      );
      if(response.statusCode != 200) {
        throw Exception("Failed to update settings in db ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //get user's settings back
  static Future<SettingsModel> getUsersSettings(String uid) async {
    final url = Uri.parse("$baseUrl/users/settings/$uid");
    try {
      final response = await http.get(url);

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

  //get multiple users
  static Future<List<CardData>> getMultipleUsers(String uid, Set<int> seenIds) async {
    final url = Uri.parse("$baseUrl/users/feed/$uid");
    try {
      final response = await http.post(url,
      headers: {
        "Content-Type": "application/json"
      },
      body: jsonEncode({
        "firebase_token": uid,
        "seen_ids": seenIds.toList(),
      }));

      if(response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        List<CardData> cards = body.map((dynamic item) => CardData.fromPostgresRow(item)).toList();
        return cards;
      }
      else if(response.statusCode != 200) {
        return [];
      }
      else {
        throw Exception("Failed to get data ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //like endpoints
  //register a like/match in the db
  static Future<bool> registerLike({
    required String uid,
    required int likedUserId,
    bool isSuperLike = false,
  }) async {
    final url = Uri.parse("$baseUrl/likes/$uid"); 

    try {
      final response = await http.post(url, 
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "firebase_token": uid,
        "liked_id": likedUserId,
        "is_super_like": isSuperLike,
      }));
      if(response.statusCode == 200) {  
        final data = jsonDecode(response.body);
        return data["is_match"] ?? false;
      }
      else  {
        throw Exception("Failed to register like ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //get matches aka dms
  static Future<List<MatchModel>> getMatches({
    required String uid,
  }) async {
    final url = Uri.parse("$baseUrl/matches/$uid");
    
    try {
      final response = await http.get(url);

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

  //post message to db
  static Future<bool> postMessage({
    required String uid,
    required int matchId,
    required String content,
  }) async {
    final url = Uri.parse("$baseUrl/messages/store");

    try {
      final response = await http.post(url,
        headers: {
            "Content-Type": "application/json", 
          },
        body: jsonEncode({
          "firebase_token": uid,
          "match_id": matchId,
          "content": content,
        }),
      );

      if(response.statusCode != 200) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  //get all messages from a conversation in reverse chronological order (last to first)
  static Future<List<MessageModel>> getMessages(String uid, int myUserId, int matchId) async {
    final url = Uri.parse("$baseUrl/messages/$matchId?firebase_token=$uid");

    try {
      final response = await http.get(url);

      if(response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MessageModel.fromJson(json, myUserId)).toList();
      } else {
        throw Exception("Failed to get messages ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }

  //get all likes 
  static Future<List<LikerModel>> getLikes(String uid) async {
    final url = Uri.parse("$baseUrl/likes/$uid");

    try {
      final response = await http.get(url);

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

  //get user photos
  static Future<List<PhotosModel>> getPhotos(String uid) async {
    final url = Uri.parse("$baseUrl/photos/$uid");

    try {
      final response = await http.get(url);

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

  //upload a photo to database
  static Future<bool> uploadPhoto({
    required String uid,
    required String photoUrl,
    required int displayOrder,
  }) async {
    final url = Uri.parse("$baseUrl/photos");

    try {
      final response = await http.post(url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "firebase_token": uid,
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

  //upload the photo file to firebase cloud and return the url
  static Future<String?> uploadToFirebase(File imageFile, String uid) async {
    try {
      //to ensure unique file name and path
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
}