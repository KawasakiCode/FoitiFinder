//The bell's list: what each kind says, and what is still tappable.
//
//TESTABLE BECAUSE THE DATA COMES FROM A PROVIDER. The page never calls the
//API itself, so a fake provider is the whole test harness - which is the
//difference between this file and the match page's, where the network is
//reached through static methods.
//
//WHAT THESE PIN DOWN is the rule that cost a real match: a notification whose
//match has been answered is not a link any more. The row does not change when
//you answer - the thing it points at does - so `actionable` comes from the
//server and the page must obey it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/notification_model.dart';
import 'package:foitifinder/pages/main_pages/notifications_page.dart';
import 'package:foitifinder/providers/notifications_provider.dart';
import 'package:provider/provider.dart';

class FakeNotifications extends NotificationsProvider {
  FakeNotifications(this._fake);

  List<AppNotification> _fake;
  final List<int> readCalls = [];
  int loadCalls = 0;

  @override
  List<AppNotification> get items => _fake;

  @override
  bool get isLoading => false;

  @override
  Future<void> load() async => loadCalls++;

  @override
  Future<void> markRead(AppNotification note) async {
    readCalls.add(note.id);
    _fake = [
      for (final item in _fake) item.id == note.id ? item.asRead() : item,
    ];
    notifyListeners();
  }
}

AppNotification note({
  int id = 1,
  NotificationKind kind = NotificationKind.matchWaiting,
  int? matchId = 7,
  int? otherUserId = 2,
  String? otherName = 'Maria',
  bool read = false,
  bool actionable = true,
  bool otherConfirmed = true,
}) {
  return AppNotification(
    id: id,
    kind: kind,
    matchId: matchId,
    otherUserId: otherUserId,
    otherName: otherName,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    read: read,
    actionable: actionable,
    otherConfirmed: otherConfirmed,
  );
}

//THE DEFAULT TEST SURFACE IS 800x600, which is nothing like a phone: a page
//built for a tall narrow screen overflows it and the failure then says
//nothing about the behaviour under test.
//
//AND IT IS WIDER THAN A REAL PHONE ON PURPOSE. Widget tests do not load the
//app's font - every glyph becomes a full-width box, so a label measures
//roughly 40% wider here than on a device ("Share my Instagram" overflowed a
//360pt button by 12px, which it does not do in the app). 440pt leaves room
//for that distortion without pretending to be a tablet.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1320, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<FakeNotifications> pumpPage(
  WidgetTester tester,
  List<AppNotification> rows,
) async {
  usePhoneSurface(tester);
  final provider = FakeNotifications(rows);
  await tester.pumpWidget(
    ChangeNotifierProvider<NotificationsProvider>.value(
      value: provider,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NotificationsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

//the opacity wrapper the row is drawn inside
double rowOpacity(WidgetTester tester, String titleText) {
  final opacity = tester.widget<Opacity>(
    find
        .ancestor(of: find.text(titleText), matching: find.byType(Opacity))
        .first,
  );
  return opacity.opacity;
}

ListTile tileFor(WidgetTester tester, String titleText) {
  return tester.widget<ListTile>(
    find.ancestor(of: find.text(titleText), matching: find.byType(ListTile)).first,
  );
}

void main() {
  testWidgets('an empty bell explains itself instead of showing nothing',
      (tester) async {
    await pumpPage(tester, []);
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  testWidgets('opening the page asks the server again', (tester) async {
    //a push may have arrived while the app was closed, and this page is where
    //the user explicitly asks "what happened?"
    final provider = await pumpPage(tester, [note()]);
    expect(provider.loadCalls, 1);
  });

  group('what each kind says', () {
    testWidgets('a match waiting on you names them and asks for a decision',
        (tester) async {
      await pumpPage(tester, [note(kind: NotificationKind.matchWaiting)]);
      expect(find.text('Maria matched with you'), findsOneWidget);
      expect(find.textContaining('already said yes'), findsOneWidget);
    });

    testWidgets('your OWN pending match does not claim they said yes',
        (tester) async {
      //the same kind reaches both sides; only one of them can be told that
      await pumpPage(tester, [
        note(kind: NotificationKind.matchWaiting, otherConfirmed: false),
      ]);
      expect(find.textContaining('already said yes'), findsNothing);
      expect(find.textContaining('finish sharing'), findsOneWidget);
    });

    testWidgets('a reveal points at the handle', (tester) async {
      await pumpPage(tester, [note(kind: NotificationKind.matchRevealed)]);
      expect(find.text("You're connected with Maria"), findsOneWidget);
    });

    testWidgets('a decline says nothing was shared', (tester) async {
      await pumpPage(tester, [
        note(kind: NotificationKind.matchDeclined, matchId: null, actionable: false),
      ]);
      expect(find.text("Maria didn't go ahead"), findsOneWidget);
      expect(find.textContaining('Nothing was shared'), findsOneWidget);
    });

    testWidgets('a nameless row still renders rather than being dropped',
        (tester) async {
      //a deleted account leaves other_user_id null; a missing row would be a
      //silent gap in the list
      await pumpPage(tester, [note(otherName: null)]);
      expect(find.textContaining('Someone'), findsWidgets);
    });
  });

  group('read and unread', () {
    testWidgets('an unread row is fully opaque and bold', (tester) async {
      await pumpPage(tester, [note(read: false)]);
      expect(rowOpacity(tester, 'Maria matched with you'), 1);
    });

    testWidgets('a read row is dimmed but still there', (tester) async {
      //never removed: a revealed Instagram is the one thing somebody may come
      //back for days later
      await pumpPage(tester, [note(read: true)]);
      expect(rowOpacity(tester, 'Maria matched with you'), lessThan(1));
      expect(find.text('Maria matched with you'), findsOneWidget);
    });

    testWidgets('tapping marks it read', (tester) async {
      final provider = await pumpPage(tester, [note()]);
      await tester.tap(find.text('Maria matched with you'));
      await tester.pump();
      expect(provider.readCalls, [1]);

      //THE TAP ALSO PUSHES THE MATCH PAGE, whose buttons arm on a timer. Left
      //running, the test ends with a pending timer and fails for a reason
      //that has nothing to do with what it is checking - so settle the route
      //and then wait the timer out.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
    });
  });

  group('what is still tappable', () {
    testWidgets('an answered match is not a link any more', (tester) async {
      //THE BUG THIS PREVENTS: reopening an answered match put a decline button
      //in front of somebody and deleted a completed match
      await pumpPage(tester, [note(read: true, actionable: false)]);
      expect(tileFor(tester, 'Maria matched with you').onTap, isNull);
    });

    testWidgets('a declined match leads nowhere', (tester) async {
      await pumpPage(tester, [
        note(
          kind: NotificationKind.matchDeclined,
          matchId: null,
          actionable: false,
          read: true,
        ),
      ]);
      expect(tileFor(tester, "Maria didn't go ahead").onTap, isNull);
    });

    testWidgets('an unread row is tappable even when it leads nowhere',
        (tester) async {
      //otherwise it could never be marked read, and the badge would never clear
      await pumpPage(tester, [
        note(kind: NotificationKind.matchDeclined, matchId: null,
             actionable: false, read: false),
      ]);
      expect(tileFor(tester, "Maria didn't go ahead").onTap, isNotNull);
    });

    testWidgets('a row the server calls actionable but that has no match '
        'is not opened', (tester) async {
      //belt and braces: canOpen needs the ids too, so a mismatched payload
      //cannot push a page with a null match id
      final provider = await pumpPage(tester, [
        note(actionable: true, matchId: null, read: false),
      ]);
      await tester.tap(find.text('Maria matched with you'));
      await tester.pumpAndSettle();
      //marked read, but nothing was pushed on top
      expect(provider.readCalls, [1]);
      expect(find.byType(NotificationsPage), findsOneWidget);
    });
  });
}
