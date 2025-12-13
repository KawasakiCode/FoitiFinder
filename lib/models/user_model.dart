//user model for the user that will be sent to the database
//email and password are missing because they are on firebase and not in the database
//the database and firebase are connected through the firebase_token (uid) to find specific users

class UserModel{
  final String uid;
  final String username;
  final String? fullName;
  final String? bio;
  final int? age;
  final String? imageUrl;

  UserModel({
    required this.uid,
    required this.username,
    required this.fullName,
    this.bio,
    this.age,
    this.imageUrl
  });

  //convert json to usermodel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel ( 
      uid: json['firebase_token'] ?? (throw Exception("Critical: uid missing")),
      username: json['username'] ?? (throw Exception("Critical: username missing")),
      fullName: json['full_name'],
      bio: json['bio'],
      age: json['age'],
      imageUrl: json['profile_picture']
    );
  }

  //convert usermodel object to map
  Map<String, dynamic> toMap() {
    return {
      'firebase_token': uid,
      'username': username,
      'full_name': fullName,
      'bio': bio,
      'age': age,
      'profile_picture': imageUrl,
    };
  }
}