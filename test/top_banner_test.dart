//The in-app banner that stands in for a push while the app is in front.
//
//WHY IT IS TESTED AT ALL, when it is twenty lines of animation: it is the
//only thing that tells somebody a match changed while they were swiping, and
//every way it can fail is silent. It does not appear, or it appears and
//cannot be tapped, or it never leaves - and none of those throw.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/widgets/top_banner.dart';

Future<void> pumpHost(
  WidgetTester tester, {
  required void Function(BuildContext) onPressed,
}) async {
  tester.view.physicalSize = const Size(1320, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onPressed(context),
              child: const Text('fire'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('it drops in and says what happened', (tester) async {
    await pumpHost(tester,
        onPressed: (context) =>
            showTopBanner(context, message: "It's a match"));

    await tester.tap(find.text('fire'));
    await tester.pumpAndSettle();

    expect(find.text("It's a match"), findsOneWidget);
  });

  testWidgets('it leaves on its own', (tester) async {
    //A NOTICE, NOT A DIALOG. Somebody swiping should not have to dismiss
    //something to carry on, and a banner that waits forever becomes part of
    //the furniture.
    await pumpHost(tester,
        onPressed: (context) =>
            showTopBanner(context, message: "It's a match"));

    await tester.tap(find.text('fire'));
    await tester.pumpAndSettle();
    expect(find.text("It's a match"), findsOneWidget);

    await tester.pump(kTopBannerVisible);
    await tester.pumpAndSettle();
    expect(find.text("It's a match"), findsNothing);
  });

  testWidgets('tapping it opens what it is about', (tester) async {
    var opened = false;
    await pumpHost(tester,
        onPressed: (context) => showTopBanner(
              context,
              message: "It's a match",
              onTap: () => opened = true,
            ));

    await tester.tap(find.text('fire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("It's a match"));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    //and it is gone, rather than left over the thing it just opened
    expect(find.text("It's a match"), findsNothing);
  });

  testWidgets('the callback waits for the exit animation', (tester) async {
    //ORDER MATTERS. Opening a profile while this is still sliding puts a
    //route transition and this animation on the same frames, which is the
    //stutter the notification path was cleaned up to remove. So the open is
    //deferred until the banner is done leaving, not fired on the tap.
    var opened = false;
    await pumpHost(tester,
        onPressed: (context) => showTopBanner(
              context,
              message: "It's a match",
              onTap: () => opened = true,
            ));

    await tester.tap(find.text('fire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("It's a match"));

    //mid-exit: the tap has registered and nothing has been opened yet
    await tester.pump(const Duration(milliseconds: 60));
    expect(opened, isFalse);

    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });

  testWidgets('a second one replaces the first', (tester) async {
    //TWO AT THE SAME OFFSET WOULD COVER EACH OTHER. A confirm and a reveal
    //can land seconds apart, and the newer one is the one worth reading.
    await pumpHost(tester, onPressed: (context) {
      showTopBanner(context, message: 'first');
      showTopBanner(context, message: 'second');
    });

    await tester.tap(find.text('fire'));
    await tester.pumpAndSettle();

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('tapping twice only opens once', (tester) async {
    //the exit animation is 260ms of tappable banner, and opening the same
    //profile twice is how two identical routes end up stacked
    var opens = 0;
    await pumpHost(tester,
        onPressed: (context) => showTopBanner(
              context,
              message: "It's a match",
              onTap: () => opens++,
            ));

    await tester.tap(find.text('fire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("It's a match"));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text("It's a match"), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(opens, 1);
  });
}
