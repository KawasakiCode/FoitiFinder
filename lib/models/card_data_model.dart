//declaration of card class and model
//grabs necessary user data from db to show in the swipe cards

class CardData {
  int id;
  String username;
  String? bio;
  int? age;
  List<String> photos;


  CardData({
    required this.id,
    required this.username,
    required this.bio,
    required this.age,
    this.photos = const [],
  });

  factory CardData.fromPostgresRow(Map<String, dynamic> row) {
    return CardData(  
      id: row['id'],
      username: row['username'],
      bio: row['bio'],
      age: row['age'],
      photos: (row['photos'] as List?) 
      ?.map((item) => item.toString()).toList() ?? [],
    );
  }
}