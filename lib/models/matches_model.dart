class MatchModel {
  final int matchId;
  final int userAid;
  final int userBid;
  final String imageUrl;

  MatchModel({
    required this.matchId,
    required this.userAid,
    required this.userBid,
    required this.imageUrl,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(  
      matchId: json['match_id'],
      userAid: json['user_a_id'],
      userBid: json['user_b_id'],
      imageUrl: json['image_url'],
    );
  }
}