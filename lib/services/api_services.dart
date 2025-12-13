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
        }),
      );

      if (response.statusCode != 200 || response.statusCode != 201) {
        throw Exception("Failed to create user");
      }
    } catch (e) {
      rethrow;
    }
  }

  //update pfp (runs every time user updates pfp)
  static Future<void> updateProfilePicture(String uid, String newUrl) async {
    final url = Uri.parse('$baseUrl/users/$uid/image');
    try {
      final response = await http.patch(  
        url,
        headers: {"Content-type": "application/json"},
        body: jsonEncode({
          "profile_picture": newUrl,
        }),
      );
      if(response.statusCode != 200) {
        throw Exception("failed to update image in db ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<UserModel> getUserData(String uid) async {
    final url = Uri.parse('$baseUrl/users/$uid');
    try {
      final response = await http.get(url);

      if(response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return UserModel.fromJson(data);
      }
      else {
        throw Exception("Failed to get data ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }
}