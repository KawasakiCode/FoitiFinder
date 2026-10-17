//The profile content has to LEAVE the way it arrived when the page is opened
//from a likes tile - there is no growing photo to hide it there, so a body
//that simply stops being painted reads as the page blinking out.
//
//This has broken twice, both times invisibly to the analyzer, so it is a test
//rather than a comment.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/pages/main_pages/profile_detail_page.dart';

Offset _bodyOffset(WidgetTester tester) {
  final slide = tester.widget<SlideTransition>(
    find.byKey(kProfileBodySlideKey),
  );
  return slide.position.value;
}

void main() {
  Future<void> openProfile(WidgetTester tester, {Object? actionsHeroTag}) async {
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
                    actionsHeroTag: actionsHeroTag,
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
  }

  testWidgets('arrives from the right and settles', (tester) async {
    await openProfile(tester);
    expect(_bodyOffset(tester), Offset.zero);
  });

  testWidgets('slides back out to the right when popped', (tester) async {
    await openProfile(tester);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();

    //one frame to start the reverse, then partway through it
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final offset = _bodyOffset(tester);
    expect(
      offset.dx,
      greaterThan(0),
      reason: 'the body should be travelling right, not sitting still',
    );

    //and still moving further out later in the close
    final earlier = offset.dx;
    await tester.pump(const Duration(milliseconds: 150));
    expect(_bodyOffset(tester).dx, greaterThan(earlier));

    await tester.pumpAndSettle();
  });

  testWidgets('the real buttons stay hidden while a copy of them flies',
      (tester) async {
    //opened from a swipe card: the button row is a Hero, so the pair in this
    //page must be invisible until the flight lands, or there are two.
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
                    actionsHeroTag: 'actions-1',
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

    //the offstage measuring frame, then partway into the flight
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final mid = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('decision-bar')),
        matching: find.byType(Opacity),
      ),
    );
    expect(mid.opacity, 0, reason: 'the copy in flight is the only pair');

    await tester.pumpAndSettle();
    final after = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('decision-bar')),
        matching: find.byType(Opacity),
      ),
    );
    expect(after.opacity, 1, reason: 'they take over once it has landed');
  });
}
