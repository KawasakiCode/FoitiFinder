//What a swipe and a match confirmation answer with.
//
//Two tiny types rather than a bool and a Map: the swipe used to return only
//"was it a match", and the match page needs the id of the match it is deciding
//about. A bool cannot carry it, and reading raw json at the call site puts the
//backend's key names into the UI.

class SwipeResult {
  final bool isMatch;
  //null unless this swipe completed a match - and also null when a backend too
  //old to send it answers, which is why the page is only opened when both this
  //and isMatch are present
  final int? matchId;

  const SwipeResult({required this.isMatch, this.matchId});

  //no match, nothing to open: what a failed-but-swallowed swipe reports
  static const SwipeResult none = SwipeResult(isMatch: false);
}

//The answer to saying yes.
class MatchConfirmation {
  //true when the OTHER side had already said yes, so this confirmation
  //completed the exchange
  final bool revealed;
  final String otherName;
  //only ever set when revealed is true
  final String? instagramHandle;

  const MatchConfirmation({
    required this.revealed,
    required this.otherName,
    this.instagramHandle,
  });
}
