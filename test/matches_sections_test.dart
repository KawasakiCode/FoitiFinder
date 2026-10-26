//How the matches page splits a list of matches into its three sections.
//
//WHY THIS IS WORTH A TEST AND THE OLD FLAT GRID WAS NOT. A flat list shows
//everything it is given; a grouped one shows what the grouping claims. If a
//combination of the three server flags falls through every branch, the match
//is gone from the page - no error, no empty state, just a person who matched
//with you and is nowhere. So the partition is checked for totality against
//every combination, not only the three that are supposed to occur.
//
//MatchesPage itself is not pumped here: it reaches for FirebaseAuth and
//ApiService in initState, which is why the grouping lives in the model. The
//same reasoning as match_actions_test.

import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/models/matches_model.dart';

MatchModel match(
  int id, {
  bool iConfirmed = false,
  bool theyConfirmed = false,
  bool revealed = false,
}) {
  return MatchModel(
    matchId: id,
    otherUserId: id,
    otherUserName: 'Person $id',
    iConfirmed: iConfirmed,
    theyConfirmed: theyConfirmed,
    revealed: revealed,
  );
}

List<int> ids(List<MatchModel> matches) =>
    matches.map((match) => match.matchId).toList();

void main() {
  group('which section a match lands in', () {
    test('nobody has answered: yours to decide', () {
      //the ordinary deck match: you completed it, so you answer first and
      //they have not been told anything yet
      final sections = MatchSections.of([match(1)]);
      expect(ids(sections.yourTurn), [1]);
      expect(sections.waitingOnThem, isEmpty);
      expect(sections.connected, isEmpty);
    });

    test('they answered and you have not: still yours to decide', () {
      final sections = MatchSections.of([match(1, theyConfirmed: true)]);
      expect(ids(sections.yourTurn), [1]);
    });

    test('you answered and they have not: waiting on them', () {
      final sections = MatchSections.of([match(1, iConfirmed: true)]);
      expect(ids(sections.waitingOnThem), [1]);
      expect(sections.yourTurn, isEmpty);
    });

    test('revealed: connected', () {
      final sections = MatchSections.of([
        match(1, iConfirmed: true, theyConfirmed: true, revealed: true),
      ]);
      expect(ids(sections.connected), [1]);
      expect(sections.yourTurn, isEmpty);
      expect(sections.waitingOnThem, isEmpty);
    });

    test('revealed outranks the booleans under it', () {
      //the server's verdict includes both handles, so a row it calls revealed
      //is revealed even if the flags beneath look like something else
      final sections = MatchSections.of([match(1, revealed: true)]);
      expect(ids(sections.connected), [1]);
    });
  });

  test('every combination of the three flags lands somewhere', () {
    final all = <MatchModel>[];
    var id = 0;
    for (final mine in [false, true]) {
      for (final theirs in [false, true]) {
        for (final revealed in [false, true]) {
          all.add(match(id++,
              iConfirmed: mine, theyConfirmed: theirs, revealed: revealed));
        }
      }
    }

    final sections = MatchSections.of(all);
    expect(sections.total, all.length);

    //and no match is in two sections at once
    final placed = [
      ...ids(sections.yourTurn),
      ...ids(sections.waitingOnThem),
      ...ids(sections.connected),
    ];
    expect(placed.toSet().length, all.length);
  });

  test('inside your turn, the ones waiting on you come first', () {
    //THE REASON THE ORDER IS NOT THE SERVER'S. get_matches returns newest
    //first, which puts a match nobody has seen above one somebody has been
    //waiting on for two days. Both need the same press; only one has a person
    //behind it.
    final sections = MatchSections.of([
      match(1),
      match(2, theyConfirmed: true),
      match(3),
      match(4, theyConfirmed: true),
    ]);
    expect(ids(sections.yourTurn), [2, 4, 1, 3]);
  });

  test('theyAreWaitingOnMe is the badge condition, and nothing else', () {
    expect(match(1).theyAreWaitingOnMe, isFalse);
    expect(match(1, theyConfirmed: true).theyAreWaitingOnMe, isTrue);
    //already answered, so it is not your turn at all
    expect(
      match(1, iConfirmed: true, theyConfirmed: true).theyAreWaitingOnMe,
      isFalse,
    );
  });
}
