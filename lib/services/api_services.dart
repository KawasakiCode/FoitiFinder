import 'dart:convert';
import 'package:foitifinder/models/user_model.dart';
import 'package:http/http.dart' as http;

class ApiService {
  //test for emulator
  static const String baseUrl = "http://10.0.2.2:8000"; 
  //test for real phone
  //static const String baseUrl = "http://127.0.0.1:8000"; 

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
    required String? interests
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
          "bio": bio,
          "age": age,
          "image_url": imageUrl,
          "gender": gender,
          "min_age_range": minAgeRange,
          "max_age_range": maxAgeRange,
          "show_out_of_range": showOutOfRange,
          "is_balanced": isBalanced,
          "interests": interests,
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
    if (bio != null) data['bio'] = bio;
    if (age != null) data['age'] = age;
    if (imageUrl != null) data['profile_picture'] = imageUrl;
    if (gender != null) data['gender'] = gender;
    if (minAgeRange != null) data['min_age_range'] = minAgeRange;
    if (maxAgeRange != null) data['max_age_range'] = maxAgeRange;
    if (showOutOfRange != null) data['show_out_of_age_range'] = showOutOfRange;
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
}