//user model for the user that will be sent to the database
//email and password are missing because they are on firebase and not in the database
//the database and firebase are connected through the firebase_token (uid) to find specific users

class UserModel{
  final int? id;
  final String uid;
  final String username;
  final String? fullName;
  final String? bio;
  final int? age;
  final String? imageUrl;
  final String? gender;
  final int? minAgeRange;
  final int? maxAgeRange;
  final bool? showOutOfRange;
  final bool? isBalanced;
  final String? interests;
  final bool hasFinishedSetUp;

  UserModel({
    required this.uid,
    required this.username,
    required this.fullName,
    required this.hasFinishedSetUp,
    this.id,
    this.bio,
    this.age,
    this.imageUrl,
    this.gender, 
    this.minAgeRange,
    this.maxAgeRange,
    this.showOutOfRange,
    this.isBalanced,
    this.interests    
  });

  //convert json to usermodel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel ( 
      uid: json['firebase_token'] ?? (throw Exception("Critical: uid missing")),
      username: json['username'] ?? (throw Exception("Critical: username missing")),
      hasFinishedSetUp: json['has_finished_set_up'] ?? (throw Exception("Critical: finishedSetUp missing")),
      fullName: json['full_name'],
      id: json['id'],
      bio: json['bio'],
      age: json['age'],
      imageUrl: json['profile_picture'],
      gender: json['gender'],
      minAgeRange: json['min_age_range'],
      maxAgeRange: json['max_age_range'],
      showOutOfRange: json['show_out_of_range'],
      isBalanced: json['is_balanced'],
      interests: json['interests'],
    );
  }

  //convert usermodel object to map (map is like json)
  Map<String, dynamic> toMap() {
    return {
      'firebase_token': uid,
      'username': username,
      'has_finished_set_up': hasFinishedSetUp,
      'full_name': fullName,
      'id': id,
      'bio': bio,
      'age': age,
      'profile_picture': imageUrl,
      'gender': gender,
      'min_age_range': minAgeRange,
      'max_age_range': maxAgeRange,
      'show_out_of_range': showOutOfRange,
      'is_balanced': isBalanced,
      'interests': interests,
    };
  }
}