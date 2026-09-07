//Grabs necessary data for the cards that 
//appear in the users likes page
//Only contains people that liked the user

class LikerModel {
  final int id;
  final String name;
  final int age;
  final String imageUrl;

  LikerModel({
    required this.id,
    required this.name,
    required this.age,
    required this.imageUrl, 
  });

  factory LikerModel.fromJson(Map<String, dynamic> json) {
    return LikerModel(  
      id: json['id'],
      name: json['name'],
      age: json['age'] ?? 18,
      imageUrl: json['image_url'] ?? "https://picsum.photos/200"
    );
  }
}