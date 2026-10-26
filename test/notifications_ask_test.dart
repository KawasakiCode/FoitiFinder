//The screen that asks for notification permission at the end of setup.
//
//WHAT IS ACTUALLY WORTH PINNING is not the layout, it is the two things that
//make a pre-prompt a pre-prompt rather than a nag:
//
//  * 'Not now' must NOT reach the OS dialog. Android permanently denies after
//    two dismissals and the only recovery is the system settings screen, so a
//    dismissed OS prompt is one of two chances spent. A dismissed screen like
//    this one costs nothing.
//  * Either answer must end the question. SetupWrapper shows this screen
//    until the flag is set, so an answer that did not set it would reappear
//    on the next launch - which is the nagging the pre-prompt avoids.
//
//WHAT IS NOT TESTED is the OS prompt itself: requestPermission is a platform
//call with no seam here, and a widget test has no platform to answer it. The
//positive path is therefore checked only up to the flag, which is the part
//this app owns.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/sign_up_set_up/notifications_page.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsProvider> pumpAsk(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  //see notifications_page_test.dart: wider than a phone, because a widget
  //test loads no app font and every label measures wider than on a device
  tester.view.physicalSize = const Size(1320, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues(prefs);
  final provider = SettingsProvider(await SharedPreferences.getInstance());

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: provider,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NotificationsPage(),
      ),
    ),
  );
  await tester.pump();
  return provider;
}

void main() {
  testWidgets('it says which two pushes the app sends', (tester) async {
    //'ALLOW NOTIFICATIONS' IS A QUESTION NOBODY CAN ANSWER. These are the
    //only two the backend sends, and both are somebody waiting on the user -
    //which is the whole case for saying yes.
    await pumpAsk(tester);

    expect(find.text('Know when you match'), findsOneWidget);
    expect(find.textContaining('waiting on your answer'), findsOneWidget);
    expect(find.textContaining('share their Instagram back'), findsOneWidget);
    expect(find.textContaining('Nothing else'), findsOneWidget);
  });

  testWidgets('declining is a real option, not a hidden one', (tester) async {
    //a prompt with only one way out is how somebody ends up permanently
    //denying it at the OS instead, where it cannot be asked again
    await pumpAsk(tester);

    expect(find.text('Turn on notifications'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('declining ends the question', (tester) async {
    final provider = await pumpAsk(tester);
    expect(provider.hasBeenAskedAboutNotifications, isFalse);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    //SetupWrapper reads this and moves on to the deck
    expect(provider.hasBeenAskedAboutNotifications, isTrue);
  });

  testWidgets('declining does not record a preference for silence',
      (tester) async {
    //THE DISTINCTION. They declined a prompt, which is not the same as asking
    //never to be told - so the setting is left alone rather than written off,
    //and granting permission later at the OS level starts the pushes working
    //without having to find the switch.
    final provider = await pumpAsk(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('match_notifications_enabled'), isNull);
    expect(provider.matchNotificationsEnabled, isFalse);
  });

  testWidgets('a second launch does not ask again', (tester) async {
    //the flag is already set, so SetupWrapper would never build this screen -
    //this checks the flag it reads, which is the contract between them
    final provider = await pumpAsk(tester, prefs: {'notifications_asked': true});
    expect(provider.hasBeenAskedAboutNotifications, isTrue);
  });
}
