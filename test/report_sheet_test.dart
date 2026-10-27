//The report sheet: three steps, and the four ways out of them.
//
//THE WAYS OUT ARE THE WHOLE TEST. Three steps deep, X must close everything
//from any depth, back must go one step, the system back must go one step
//rather than throwing the answers away, and tapping above the sheet must
//close it like X. Each of those is a line of code that looks optional and is
//the difference between a usable flow and a trap.
//
//WHAT IS NOT TESTED is the submit. ApiService is static methods over http
//with no seam behind it - the same limit as match_actions_test - so what the
//endpoint does with a report lives in backend/tests/test_reports.py, where
//the swipe, the hidden match and the refusals can be checked properly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/widgets/report_sheet.dart';

Future<void> openSheet(
  WidgetTester tester, {
  bool afterMatch = false,
  //NULL IS A REAL CASE, not a convenience: it is how the matches page opens
  //this sheet, and it has to take the row away rather than leave a dead one.
  VoidCallback? onNotInterested = _noop,
}) async {
  //see notifications_page_test.dart: wider and taller than a phone, because a
  //widget test loads no app font and every label measures wider than it does
  //on a device
  tester.view.physicalSize = const Size(1320, 2900);
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
              onPressed: () => showReportSheet(
                context,
                reportedUserId: 2,
                afterMatch: afterMatch,
                onNotInterested: onNotInterested,
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
}

void _noop() {}

Future<void> drillTo(WidgetTester tester, String category) async {
  await tester.tap(find.text(category));
  await tester.pumpAndSettle();
}

void main() {
  group('the first step', () {
    testWidgets('names the categories and says reports are anonymous',
        (tester) async {
      await openSheet(tester);

      expect(find.text('Report profile'), findsOneWidget);
      expect(find.textContaining('anonymous'), findsOneWidget);
      expect(find.text('Inappropriate profile content'), findsOneWidget);
      expect(find.text('Possibly under 18'), findsOneWidget);
      expect(find.text('Fake or misleading profile'), findsOneWidget);
    });

    testWidgets('offers not-interested alongside them', (tester) async {
      //THE PRESSURE VALVE. Without it, somebody who merely dislikes a profile
      //has nothing to press but an accusation, and the queue fills with
      //reports that are really passes.
      await openSheet(tester);
      expect(find.text('Not interested in this profile'), findsOneWidget);
    });

    testWidgets('and it is not a report', (tester) async {
      var passed = false;
      await openSheet(tester, onNotInterested: () => passed = true);

      await tester.tap(find.text('Not interested in this profile'));
      await tester.pumpAndSettle();

      expect(passed, isTrue);
      expect(find.text('Report profile'), findsNothing);
    });

    testWidgets('and is absent where there is nothing for it to do',
        (tester) async {
      //THE MATCHES PAGE OPENS PROFILES WITH DECISIONS OFF and discards what
      //comes back, so the row used to sit there doing nothing when tapped.
      //It is also the wrong question: you cannot be uninterested in somebody
      //whose Instagram you already have, and acting on it would mean
      //destroying a match through a button that mentions no such thing.
      await openSheet(tester, afterMatch: true, onNotInterested: null);

      expect(find.text('Not interested in this profile'), findsNothing);
      //the report categories are all still there
      expect(find.text('Inappropriate profile content'), findsOneWidget);
      expect(find.text('Harassment or unsafe behaviour'), findsOneWidget);
    });

    testWidgets('has no back arrow, because there is nothing behind it',
        (tester) async {
      await openSheet(tester);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('harassment is only offered after a match', () {
    testWidgets('hidden from a stranger in the deck', (tester) async {
      //it means what somebody did once they had your Instagram handle, which
      //cannot have happened to somebody you have not matched with
      await openSheet(tester, afterMatch: false);
      expect(find.text('Harassment or unsafe behaviour'), findsNothing);
    });

    testWidgets('shown once there is one', (tester) async {
      await openSheet(tester, afterMatch: true);
      expect(find.text('Harassment or unsafe behaviour'), findsOneWidget);
    });

    testWidgets('and its options are the after-the-fact ones', (tester) async {
      await openSheet(tester, afterMatch: true);
      await drillTo(tester, 'Harassment or unsafe behaviour');

      expect(find.text('What happened?'), findsOneWidget);
      expect(find.text('Threats or stalking'), findsOneWidget);
      expect(find.text('Made me feel unsafe'), findsOneWidget);
    });
  });

  group('the second step', () {
    testWidgets('is titled for the category it came from', (tester) async {
      //'Report profile' twice gives no sense of having moved
      await openSheet(tester);
      await drillTo(tester, 'Possibly under 18');

      expect(find.text('What makes you think so?'), findsOneWidget);
      expect(find.text('Report profile'), findsNothing);
    });

    testWidgets('lists that category and not another', (tester) async {
      await openSheet(tester);
      await drillTo(tester, 'Possibly under 18');

      expect(find.text('This person may be under 18'), findsOneWidget);
      expect(find.text('Sexual content involving a minor'), findsOneWidget);
      //from a different category
      expect(find.text('Impersonating someone real'), findsNothing);
    });

    testWidgets('every category offers a way out of the list',
        (tester) async {
      //WITHOUT 'Something else' PEOPLE PICK THE NEAREST WRONG THING, which
      //files an accusation under a heading nobody meant
      for (final category in [
        'Inappropriate profile content',
        'Possibly under 18',
        'Fake or misleading profile',
      ]) {
        await openSheet(tester);
        await drillTo(tester, category);
        expect(find.text('Something else'), findsOneWidget, reason: category);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      }
    });
  });

  group('the third step', () {
    Future<void> openDetails(WidgetTester tester) async {
      await openSheet(tester);
      await drillTo(tester, 'Inappropriate profile content');
      await drillTo(tester, 'Nudity or sexual content');
    }

    testWidgets('asks for detail and says why it matters', (tester) async {
      await openDetails(tester);

      expect(find.text('Tell us what happened'), findsOneWidget);
      expect(find.textContaining('as much detail'), findsOneWidget);
      expect(find.textContaining('confidential'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Submit report'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancel closes the whole thing', (tester) async {
      await openDetails(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Report profile'), findsNothing);
    });
  });

  group('the push', () {
    testWidgets('the two panels never overlap', (tester) async {
      //WHAT THIS REPLACED. AnimatedSwitcher handed the same builder to the
      //outgoing panel with a reversing animation, so it retraced its entrance
      //- sliding back out the side the new one was arriving from. Two panels
      //of text moving through each other, which is what it looked like.
      //
      //A push puts them on opposite sides of the viewport and moves both the
      //same way, so at no point is one readable on top of the other.
      await openSheet(tester);
      await tester.tap(find.text('Possibly under 18'));

      //TWO PUMPS, NOT ONE. A ticker reports zero elapsed on its first frame,
      //so a single pump(120ms) rebuilds with the animation still at its start
      //- the panels would be found exactly where they began.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final offsets = tester
          .widgetList<SlideTransition>(find.byType(SlideTransition))
          .map((slide) => slide.position.value.dx)
          .where((dx) => dx != 0)
          .toList();

      expect(offsets.length, 2, reason: 'both panels should be travelling');
      //one off to the left, one off to the right - never stacked
      expect(offsets.any((dx) => dx < 0), isTrue);
      expect(offsets.any((dx) => dx > 0), isTrue);

      await tester.pumpAndSettle();
    });

    testWidgets('the first panel is in place, not waiting off screen',
        (tester) async {
      //THE BUG THIS CAUGHT. The tweens map 0 to "entering from the side", so
      //a controller left at its default 0 held the very first panel a full
      //width off screen - laid out, painted, and untappable, with nothing to
      //say why.
      await openSheet(tester);

      final slides = tester
          .widgetList<SlideTransition>(find.byType(SlideTransition))
          .map((slide) => slide.position.value)
          .toList();

      expect(slides, isNotEmpty);
      expect(slides.every((offset) => offset == Offset.zero), isTrue);
    });
  });

  group('getting out', () {
    testWidgets('the back arrow goes one step', (tester) async {
      await openSheet(tester);
      await drillTo(tester, 'Fake or misleading profile');
      expect(find.text('What is misleading?'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Report profile'), findsOneWidget);
    });

    testWidgets('X closes everything from the deepest step', (tester) async {
      //backing out step by step to abandon a report is three presses to do
      //nothing
      await openSheet(tester);
      await drillTo(tester, 'Fake or misleading profile');
      await drillTo(tester, 'Impersonating someone real');
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Report profile'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the system back goes one step, not out', (tester) async {
      //A BACK GESTURE THAT THREW AWAY TWO ANSWERS WOULD BE A TRAP, and it is
      //the default behaviour for a sheet - PopScope is what prevents it.
      await openSheet(tester);
      await drillTo(tester, 'Possibly under 18');

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Report profile'), findsOneWidget);
    });

    testWidgets('and out from the first step', (tester) async {
      await openSheet(tester);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Report profile'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('tapping above the sheet closes it like X', (tester) async {
      await openSheet(tester);
      await drillTo(tester, 'Possibly under 18');

      //the barrier: the empty space left above an 80% sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('Report profile'), findsNothing);
      expect(find.text('What makes you think so?'), findsNothing);
    });
  });
}
