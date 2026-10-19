//Grabs necessary data for the cards that 
//appear in the users likes page
//Only contains people that liked the user

class LikerModel {
  final int id;
  final String name;
  final int age;
  //NULLABLE, because a liker may have no profile photo - an account from
  //before three photos were required, or one that lost them. It used to fall
  //back to a random picsum image, which showed a STRANGER'S face next to
  //somebody's name; the placeholder is the honest answer.
  final String? imageUrl;

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
      imageUrl: json['image_url'] as String?
    );
  }
}