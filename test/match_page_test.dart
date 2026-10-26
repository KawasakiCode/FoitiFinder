//The match page: the one screen in the app with a one-way door on it.
//
//WHAT IS WORTH PINNING DOWN here is not the layout, it is the guards. Sharing
//an Instagram handle cannot be undone, so: the buttons are dead for the first
//moment, sharing takes two taps, the dialog names the handle being shared, and
//cancelling sends nothing. Each of those is a decision that looks like a
//detail and would be removed by anyone tidying the file.
//
//WHAT THESE CANNOT TEST is anything past the confirm, because ApiService is
//static methods over http - there is no seam to put a fake behind. A test of
//the reveal state would need that refactor first, so the sequencing lives in
//the backend suite (test_match_flow.py) where it can be checked properly.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/pages/main_pages/match_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

//see the note in notifications_page_test.dart: wider than a phone because the
//test font makes every label wider than it is in the app
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1320, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

//THE REAL PROVIDER, WITH ITS CACHE PRE-SEEDED, rather than a fake subclass.
//ProfileProvider's constructor calls loadUser(), which reaches for
//FirebaseAuth when the cache is empty - and there is no Firebase in a test.
//Writing the user into SharedPreferences first makes it take the cache path,
//which is the path it takes on a real launch anyway.
ProfileProvider providerHolding(SharedPreferences prefs) => ProfileProvider(prefs);

Future<void> pumpMatch(
  WidgetTester tester, {
  bool fromNotification = false,
  bool theyConfirmed = false,
  String myHandle = 'my.handle',
}) async {
  usePhoneSurface(tester);
  final me = UserModel(
    uid: 'uid-me',
    name: 'Me',
    hasFinishedSetUp: true,
    hasPhotos: true,
    instagramHandle: myHandle,
  );
  SharedPreferences.setMockInitialValues({
    'user_data': jsonEncode(me.toMap()),
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ChangeNotifierProvider<ProfileProvider>.value(
      value: providerHolding(prefs),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MatchPage(
          matchId: 7,
          otherUserId: 2,
          otherName: 'Maria',
          otherAge: 21,
          fromNotification: fromNotification,
          theyConfirmed: theyConfirmed,
        ),
      ),
    ),
  );
  await tester.pump();
}

//PopScope is generic and the page writes it without a type argument, so
//byType(PopScope<Object?>) finds nothing - a predicate matches whatever it
//was instantiated as.
bool canLeave(WidgetTester tester) {
  final scope = tester
      .widgetList(find.byWidgetPredicate((widget) => widget is PopScope))
      .first as PopScope;
  return scope.canPop;
}

void main() {
  group('the decision', () {
    testWidgets('it says who, and what happens next', (tester) async {
      await pumpMatch(tester);
      expect(find.text("It's a match"), findsOneWidget);
      expect(find.text('Maria, 21'), findsOneWidget);
      //the page has to explain the exchange, because nothing else in the app
      //does at the moment it matters
      expect(find.textContaining('no chat'), findsOneWidget);
      expect(find.text('Share my Instagram'), findsOneWidget);
      expect(find.text('Not interested'), findsOneWidget);
    });

    testWidgets('a full profile is one tap away', (tester) async {
      //essential for the side that swiped weeks ago and has forgotten who
      //this is - deciding off one photo is how you manufacture a decline
      await pumpMatch(tester);
      expect(find.text('View full profile'), findsOneWidget);
    });

    testWidgets('arriving from a notification says THEY said yes',
        (tester) async {
      await pumpMatch(tester, fromNotification: true, theyConfirmed: true);
      expect(find.text('Maria said yes'), findsOneWidget);
    });

    testWidgets('your own pending match does not claim they said yes',
        (tester) async {
      //the same notification kind reaches both sides, and only one of them
      //has an answer to report
      await pumpMatch(tester, fromNotification: true, theyConfirmed: false);
      expect(find.text('Maria said yes'), findsNothing);
      expect(find.text("It's a match"), findsOneWidget);
    });
  });

  group('the one-way door', () {
    testWidgets('the buttons are dead for the first moment', (tester) async {
      //YOU ARRIVE HERE BY TAPPING LIKE, so your thumb is already heading for
      //the bottom of the screen and the share button lands roughly where that
      //button was. A carry-through double tap must not walk through this.
      await pumpMatch(tester);

      await tester.tap(find.text('Share my Instagram'));
      await tester.pump();
      expect(
        find.text('Share your Instagram?'),
        findsNothing,
        reason: 'a tap in the first instant must do nothing at all',
      );
    });

    testWidgets('and live shortly after', (tester) async {
      await pumpMatch(tester);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Share my Instagram'));
      await tester.pumpAndSettle();
      expect(find.text('Share your Instagram?'), findsOneWidget);
    });

    testWidgets('sharing takes two taps, and the second one names the handle',
        (tester) async {
      await pumpMatch(tester);
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Share my Instagram'));
      await tester.pumpAndSettle();

      //NAMES IT OUT LOUD. The thing worth checking at this moment is WHAT is
      //about to be shared, not whether the user meant to tap - a typo caught
      //here costs nothing, and after this nobody can take it back.
      expect(find.textContaining('my.handle'), findsOneWidget);
      expect(find.textContaining('cannot be taken back'), findsOneWidget);
    });

    testWidgets('cancelling the dialog sends nothing and stays put',
        (tester) async {
      await pumpMatch(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Share my Instagram'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Share your Instagram?'), findsNothing);
      //still on the decision, nothing confirmed
      expect(find.text('Share my Instagram'), findsOneWidget);
      expect(find.text('Waiting for Maria'), findsNothing);
    });
  });

  group('leaving', () {
    testWidgets('there is a way out that is not a decision', (tester) async {
      //THE BUG THIS FIXES. The only non-committal option used to be 'Not
      //interested', which DELETES the match - so a moment of doubt about a
      //swipe cost the match outright. Doubt now costs nothing.
      await pumpMatch(tester);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('leaving explains where the match went, and for how long',
        (tester) async {
      //NOT A CONFIRMATION - leaving is harmless. It is the only place the
      //three-day deadline is stated to somebody who has not agreed to it
      //anywhere else, at the moment they are looking at the match.
      await pumpMatch(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 days'), findsOneWidget);
      expect(find.textContaining('matches page'), findsOneWidget);
      //and that the other side learns nothing, which is what makes it safe
      expect(find.textContaining('not told'), findsOneWidget);
    });

    testWidgets('dismissing that dialog keeps you on the match',
        (tester) async {
      //a tap outside is not a decision to leave
      await pumpMatch(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stay here'));
      await tester.pumpAndSettle();

      expect(find.text('Share my Instagram'), findsOneWidget);
    });

    testWidgets('the system back is still intercepted, not blocked',
        (tester) async {
      //canPop stays false so the gesture reaches onPopInvokedWithResult and
      //gets the same dialog. False here means 'ask first', not 'trapped'.
      await pumpMatch(tester);
      expect(canLeave(tester), isFalse);
    });

    testWidgets('the side that arrived from a notification leaves at once',
        (tester) async {
      //NO DIALOG FOR THEM. They came from a notification about a match that
      //was already on their matches page, so leaving puts them back where
      //they can already see it - there is nothing to explain.
      await pumpMatch(tester, fromNotification: true, theyConfirmed: true);
      expect(canLeave(tester), isTrue);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 days'), findsNothing);
    });
  });
}
