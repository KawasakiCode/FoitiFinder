//The update wall, and the three ways it must NOT appear.
//
//THIS IS A KILL SWITCH FOR BUILDS, so its failure modes are asymmetric. A
//wall that fails to appear leaves an old build running a bit longer, which is
//what was happening anyway. A wall that appears when it should not has bricked
//a working app on somebody's phone, and they cannot do anything about it
//because the only button goes to a store page with no newer version on it.
//
//So every uncertain answer has to mean "carry on": no network, a cold backend
//that timed out, a response that is not a number, a build that cannot say
//which build it is. Only a server that clearly says "older than N" and a
//client that clearly knows it is older than N may raise it.
//
//WHAT IS NOT TESTED HERE is the live request. ApiService is static methods
//over http with no seam to put a fake behind - the same reason given in
//match_actions_test - so the decision is tested through the comparison that
//VersionGate's own buildIsTooOld - the real function, not a copy of it - and
//the fail-open contract of minimumBuild() is stated at the method itself.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/wrappers/version_gate.dart';

void main() {
  group('when the wall goes up', () {
    test('an older build is blocked', () {
      expect(buildIsTooOld(minimum: 7, mine: 6), isTrue);
    });

    test('the exact minimum is not', () {
      //'minimum supported', not 'minimum unsupported' - an off-by-one here
      //locks out the build you just told everybody to install
      expect(buildIsTooOld(minimum: 7, mine: 7), isFalse);
    });

    test('and nor is anything newer', () {
      expect(buildIsTooOld(minimum: 7, mine: 8), isFalse);
    });
  });

  group('every uncertain answer lets the app run', () {
    test('the server did not answer, or answered something unusable', () {
      //offline, a 500, a cold start that timed out, or a future backend whose
      //reply does not look like a number: minimumBuild returns null for all
      //of them, and null must never mean "block"
      expect(buildIsTooOld(minimum: null, mine: 6), isFalse);
    });

    test('the build cannot say which build it is', () {
      //buildNumber is a string and has been empty on some Android builds; a
      //client that cannot identify itself is not evidence that it is old
      expect(buildIsTooOld(minimum: 7, mine: null), isFalse);
    });

    test('neither is known', () {
      expect(buildIsTooOld(minimum: null, mine: null), isFalse);
    });
  });

  group('the wall itself', () {
    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(1320, 2700);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );
      await tester.pump();
    }

    testWidgets('says what happened, and offers only the update',
        (tester) async {
      await pump(tester, const UpdateWall());

      expect(find.text('Time to update'), findsOneWidget);
      expect(find.textContaining('no longer supported'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
    });

    testWidgets('and has no way past it', (tester) async {
      //NO 'later', NO DISMISS, NO BACK. Nothing behind this screen would
      //work, so an escape from it only leads to an app answering errors to
      //everything - which reads as a broken app rather than an old one.
      await pump(tester, const UpdateWall());

      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Later'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('the gate shows the app when it knows nothing',
        (tester) async {
      //a widget test has no platform for PackageInfo and no backend, which is
      //exactly the uncertain case - and it must come out as the app
      await pump(tester, const VersionGate(child: Text('the app')));

      expect(find.text('the app'), findsOneWidget);
      expect(find.text('Time to update'), findsNothing);
    });
  });

  test('the store link points at this app', () {
    //A PLACEHOLDER UNTIL THE PACKAGE NAME IS, TOO. The app still ships as
    //com.example.foitifinder, which Play refuses at upload - so this link is
    //wrong in exactly the same way and becomes right the day that is fixed.
    //Pinned so the two cannot be fixed separately and silently disagree.
    expect(kStoreUrl, contains('com.example.foitifinder'));
    expect(kStoreUrl, startsWith('https://play.google.com/store/apps/details'));
  });
}
