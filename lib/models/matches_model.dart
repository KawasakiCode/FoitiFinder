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

  //THEY HAVE COMMITTED AND YOU HAVE NOT, which is the one case where somebody
  //is actually sitting there waiting on you. The other half of waitingOnMe is
  //a match YOU completed: the server shows them nothing until you answer, so
  //they do not know it exists and nobody is waiting on anything.
  bool get theyAreWaitingOnMe => waitingOnMe && theyConfirmed;

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

//HOW THE MATCHES PAGE IS GROUPED.
//
//Here rather than in the page because the page cannot be pumped in a test -
//it reaches for FirebaseAuth and ApiService the moment it is built - while
//this is a pure function of a list and is checked in matches_sections_test.
//
//THE PARTITION MUST BE TOTAL. Three booleans arrive from the server and a
//grouped list has one failure a flat list cannot have: a combination that
//matches no section, which drops a real match off the page silently. So the
//tests are ordered, the last branch takes everything left, and `total` exists
//to be compared against the input length.
class MatchSections {
  //you have not answered. Ordered so the ones where they already said yes
  //come first: same button, but somebody is waiting behind one of them.
  final List<MatchModel> yourTurn;
  //you have answered, they have not. Nothing to press.
  final List<MatchModel> waitingOnThem;
  //both of you, and both handles are out.
  final List<MatchModel> connected;

  const MatchSections({
    required this.yourTurn,
    required this.waitingOnThem,
    required this.connected,
  });

  factory MatchSections.of(List<MatchModel> matches) {
    final mine = <MatchModel>[];
    final theirs = <MatchModel>[];
    final open = <MatchModel>[];

    for (final match in matches) {
      //`revealed` FIRST: it is the server's own verdict, including the
      //handles, so it outranks anything the two booleans under it imply.
      if (match.revealed) {
        open.add(match);
      } else if (match.waitingOnMe) {
        mine.add(match);
      } else {
        theirs.add(match);
      }
    }

    return MatchSections(
      yourTurn: [
        ...mine.where((match) => match.theyConfirmed),
        ...mine.where((match) => !match.theyConfirmed),
      ],
      waitingOnThem: theirs,
      connected: open,
    );
  }

  int get total => yourTurn.length + waitingOnThem.length + connected.length;
}
