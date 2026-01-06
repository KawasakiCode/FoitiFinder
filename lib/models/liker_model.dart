class LikerModel {
  final int id;
  final String username;
  final int age;
  final String imageUrl;

  LikerModel({
    required this.id,
    required this.username,
    required this.age,
    required this.imageUrl,
  });

  factory LikerModel.fromJson(Map<String, dynamic> json) {
    return LikerModel(  
      id: json['id'],
      username: json['username'],
      age: json['age'] ?? 18, //for now because some users may not have age yet
      imageUrl: json['image_url'] ?? "https://picsum.photos/200"
    );
  }
}