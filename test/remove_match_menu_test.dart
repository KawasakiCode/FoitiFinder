//The three-dot menu on a profile, and which of its options are on offer.
//
//'Remove match' IS THE ONLY WAY OUT OF A FINISHED MATCH. decline answers 409
//once both sides have confirmed - a handle that has been read cannot be
//unread - so without this the revealed state was permanent for the life of
//the account.
//
//WHICH MEANS IT MUST NOT APPEAR ANYWHERE ELSE. Every other state already has
//an exit, and theirs tells the other person: decline sends match_declined to
//whoever was waiting. This one tells nobody, so offering it on an unanswered
//match would be a silent way to abandon somebody mid-exchange. The server
//refuses that too, but a button that gets a 409 is still a bug.
//
//The page itself knows nothing about matches - it offers the option when it
//is given something to do, and the matches page only gives it for a revealed
//one. That is the rule under test here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/pages/main_pages/profile_detail_page.dart';

Future<void> openProfile(
  WidgetTester tester, {
  VoidCallback? onRemoveMatch,
}) async {
  //see notifications_page_test.dart: wider than a phone, because a widget
  //test loads no app font and every label measures wider than it does on a
  //device
  tester.view.physicalSize = const Size(1320, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                profileDetailRoute(
                  userId: 1,
                  photoHeroTag: 'photo-1',
                  decisions: false,
                  onRemoveMatch: onRemoveMatch,
                  preview: const PublicProfile(id: 1, name: 'Maria', age: 21),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a finished match can be removed', (tester) async {
    await openProfile(tester, onRemoveMatch: () {});

    expect(find.text('Remove match'), findsOneWidget);
    expect(find.text('Report this profile'), findsOneWidget);
  });

  testWidgets('anything else offers only the report', (tester) async {
    //null is how the matches page says "not a finished match", and how every
    //other caller in the app says "not a match at all"
    await openProfile(tester);

    expect(find.text('Remove match'), findsNothing);
    expect(find.text('Report this profile'), findsOneWidget);
  });

  testWidgets('removing takes a second tap, and says what it costs',
      (tester) async {
    var removed = false;
    await openProfile(tester, onRemoveMatch: () => removed = true);
    await tester.tap(find.text('Remove match'));
    await tester.pumpAndSettle();

    //NOTHING HAS HAPPENED YET. This is the one irreversible thing on the
    //page: there is no list of removed matches to restore from, and the match
    //is the only route back to a handle that was never saved.
    expect(removed, isFalse);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    //and the half people get wrong without being told - that this is tidying
    //your own list, not doing something to them
    expect(find.textContaining('is not told'), findsOneWidget);
    expect(find.textContaining('keeps the match'), findsOneWidget);
  });

  testWidgets('cancelling that dialog removes nothing', (tester) async {
    var removed = false;
    await openProfile(tester, onRemoveMatch: () => removed = true);
    await tester.tap(find.text('Remove match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(removed, isFalse);
  });

  testWidgets('confirming it removes, and closes the profile',
      (tester) async {
    //the page has nothing left to show once the match is gone, and the grid
    //behind it is what owns the request
    var removed = false;
    await openProfile(tester, onRemoveMatch: () => removed = true);
    await tester.tap(find.text('Remove match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(removed, isTrue);
    expect(find.text('open'), findsOneWidget);
  });
}
