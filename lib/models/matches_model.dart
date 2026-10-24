//One row of the matches page: who it is with, and whose turn it is.
//
//NO INSTAGRAM HANDLE HERE, deliberately. The handle crosses between two users
//in confirm_match and nowhere else, so this model cannot carry one even by
//accident - the profile asks for it by confirming again, which is idempotent
//and therefore a read. A list endpoint is exactly the kind of place a handle
//leaks from.
//
//`revealed` is the server's word for "both of you said yes AND both of you
//have a handle", the same condition the confirm endpoint reveals on. Not
//derived here from the two booleans, because the handles are not visible from
//this side.

class MatchModel {
  final int matchId;
  final int otherUserId;
  final String otherUserName;
  final int? otherUserAge;
  final String? imageUrl;
  final bool iConfirmed;
  final bool theyConfirmed;
  final bool revealed;

  const MatchModel({
    required this.matchId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAge,
    this.imageUrl,
    this.iConfirmed = false,
    this.theyConfirmed = false,
    this.revealed = false,
  });

  //What the tile and the profile footer branch on. Three states, in the order
  //they happen: you have not answered, you have and they have not, both have.
  bool get waitingOnMe => !iConfirmed;
  bool get waitingOnThem => iConfirmed && !revealed;

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      matchId: json['match_id'],
      otherUserId: json['other_user_id'],
      otherUserName: json['other_user_name'] ?? '',
      otherUserAge: json['other_user_age'],
      imageUrl: json['image_url'],
      //an older backend sends none of these: treat it as "nobody has answered",
      //which is the state that asks rather than the state that claims
      iConfirmed: json['i_confirmed'] ?? false,
      theyConfirmed: json['they_confirmed'] ?? false,
      revealed: json['revealed'] ?? false,
    );
  }
}
