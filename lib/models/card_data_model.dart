//declaration of card class and model
//grabs necessary user data from db to show in the swipe cards
class CardData {
  int id;
  String username;
  String? bio;
  int? age;
  String? imageUrl;


  CardData({
    required this.id,
    required this.username,
    required this.bio,
    required this.age,
    required this.imageUrl
  });

  factory CardData.fromPostgresRow(Map<String, dynamic> row) {
    return CardData(  
      id: row['id'],
      username: row['username'],
      bio: row['bio'],
      age: row['age'],
      imageUrl: "https://picsum.photos/300/400?random=${row['id']}",
    );
  }
}