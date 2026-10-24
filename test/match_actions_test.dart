//The bar under a match's profile: it must show the state the SERVER reports.
//
//WHY THAT IS THE WHOLE TEST. Three states look similar and mean completely
//different things - you have not answered, you have and they have not, both
//of you have - and the bar is the only thing standing between "waiting" and
//handing somebody an Instagram handle. Guessing the state locally is how you
//offer a share button for something already shared, or claim a connection
//that has not happened.
//
//WHAT IS NOT HERE is anything past the first tap. ApiService is static methods
//over http with no seam to put a fake behind, so confirming, declining and the
//reveal are checked in the backend suite (test_match_flow.py), where the
//sequencing can be checked properly. The revealed state is also left out here
//for that reason: it fetches the handle on init, which would be a real
//request.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/matches_model.dart';
import 'package:foitifinder/widgets/match_actions.dart';

MatchModel match({
  bool iConfirmed = false,
  bool theyConfirmed = false,
  bool revealed = false,
}) {
  return MatchModel(
    matchId: 7,
    otherUserId: 2,
    otherUserName: 'Katerina',
    otherUserAge: 21,
    iConfirmed: iConfirmed,
    theyConfirmed: theyConfirmed,
    revealed: revealed,
  );
}

//see notifications_page_test.dart: wider than a phone because widget tests do
//not load the app font, so every label measures wider than it does on a device
Future<void> pumpBar(WidgetTester tester, MatchModel model) async {
  tester.view.physicalSize = const Size(1320, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: MatchActionBar(match: model),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('nobody has answered: it asks', (tester) async {
    await pumpBar(tester, match());
    expect(find.text('Share my Instagram'), findsOneWidget);
    expect(find.text('Not interested'), findsOneWidget);
  });

  testWidgets('they answered first, you still have not: it still asks',
      (tester) async {
    //THEIR ANSWER IS NOT YOURS. This is the state that reaches you by push
    //after somebody confirms - the bar must not read as though the exchange
    //has happened, because nothing has been shared yet.
    await pumpBar(tester, match(theyConfirmed: true));
    expect(find.text('Share my Instagram'), findsOneWidget);
    expect(find.textContaining('Waiting'), findsNothing);
  });

  testWidgets('you answered, they have not: nothing to press', (tester) async {
    //A BUTTON THAT CANNOT HELP IS WORSE THAN NONE. The only thing that moves
    //this on is the other person, so offering an action here would be a lie
    //about who the flow is waiting for.
    await pumpBar(tester, match(iConfirmed: true));
    expect(find.textContaining('Katerina'), findsWidgets);
    expect(find.text('Share my Instagram'), findsNothing);
    expect(find.text('Not interested'), findsNothing);
  });

  testWidgets('a match you already shared on cannot be shared again',
      (tester) async {
    //the decline is gone too: withdrawing after you have said yes is the
    //server's 409, and a button that only ever errors is not a button
    await pumpBar(tester, match(iConfirmed: true, theyConfirmed: true));
    expect(find.text('Share my Instagram'), findsNothing);
  });
}
