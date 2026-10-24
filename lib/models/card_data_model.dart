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
  //THE ONLY INTEREST THE DECK DISCLOSES. A plain like stays invisible; a
  //super like is the sender spending one of two a week to tell you before you
  //decide. See UserCards.super_liked_you.
  final bool superLikedYou;

  CardData({
    required this.id,
    required this.name,
    required this.bio,
    required this.age,
    this.job,
    this.photos = const [],
    this.superLikedYou = false,
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
      //absent from an older backend: treated as "no", which says nothing
      //rather than claiming something that is not true
      superLikedYou: row['super_liked_you'] ?? false,
    );
  }
}