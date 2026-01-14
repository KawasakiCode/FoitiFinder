class MatchModel {
  final int matchId;
  final int userBid;
  final String userBname;
  final String? imageUrl;

  MatchModel({
    required this.matchId,
    required this.userBid,
    required this.userBname,
    required this.imageUrl,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(  
      matchId: json['match_id'],
      userBid: json['other_user_id'],
      userBname: json['other_user_name'],
      imageUrl: json['image_url'],
    );
  }
}