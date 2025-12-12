import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.0.2.2:8000"; 

  static Future<void> createUser({
    required String uid,
    required String username,
    required String email,
    required String bio,
    required int age,
    required String imageUrl,
  }) async {
    
    final url = Uri.parse('$baseUrl/users/');

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json", 
        },
        body: jsonEncode({
          "firebase_uid": uid,
          "username": username,
          "email": email,
          "bio": bio,
          "age": age,
          "image_url": imageUrl,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ User created successfully in Postgres!");
      } else {
        print("❌ Server Error: ${response.body}");
        throw Exception("Failed to create user");
      }
    } catch (e) {
      print("❌ Connection Error: $e");
      rethrow;
    }
  }
}