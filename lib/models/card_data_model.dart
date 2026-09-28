//declaration of card class and model
//grabs necessary user data from db to show in the swipe cards

class CardData {
  int id;
  String name;
  String? bio;
  int? age;
  //shown under the name on the card, beside the age
  String? job;
  List<String> photos;

  CardData({
    required this.id,
    required this.name,
    required this.bio,
    required this.age,
    this.job,
    this.photos = const [],
  });

  factory CardData.fromPostgresRow(Map<String, dynamic> row) {
    return CardData(  
      id: row['id'],
      name: row['name'],
      bio: row['bio'],
      age: row['age'],
      job: row['job'],
      photos: (row['photos'] as List?) 
      ?.map((item) => item.toString()).toList() ?? [],
    );
  }
}