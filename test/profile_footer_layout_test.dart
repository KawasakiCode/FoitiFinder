//A pinned footer must shorten the profile, not cover the end of it.
//
//THE BUG THIS CAME FROM. The footer was a Positioned child of the page's
//Stack, floating over the scroll view, and the scroll view ended with a fixed
//120px spacer to clear it. That number was measured against the deck's
//like/pass bar. MatchActionBar in its revealed state is taller - a title, an
//Instagram handle in large type, and two buttons - so on a connected match
//the last card was cut in half and could not be scrolled into view at all.
//
//WHY THIS IS A GEOMETRY TEST AND NOT A "is it in the right slot" TEST. The
//slot is the current fix, not the requirement. The requirement is that no
//amount of footer hides the bottom of the profile, and the next person to
//move this around should have to keep that true rather than keep my Scaffold
//property.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/pages/main_pages/profile_detail_page.dart';

const Key kFooterKey = Key('test-footer');

//DELIBERATELY TALLER THAN THE OLD 120px ALLOWANCE, because a footer that fits
//inside the guess proves nothing - the revealed MatchActionBar does not.
const double kTallFooterHeight = 220;

Future<void> openProfile(
  WidgetTester tester, {
  Widget? footer,
  bool decisions = false,
}) async {
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
                  decisions: decisions,
                  footer: footer,
                  preview: const PublicProfile(
                    id: 1,
                    name: 'Maria',
                    age: 21,
                    bio: 'Probably at the library. Probably not studying.',
                  ),
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

void main() {
  testWidgets('a footer shortens the scroll area instead of covering it',
      (tester) async {
    await openProfile(
      tester,
      footer: Container(
        key: kFooterKey,
        height: kTallFooterHeight,
        color: const Color(0xFF123456),
      ),
    );

    final scroll = tester.getRect(find.byType(SingleChildScrollView));
    final footer = tester.getRect(find.byKey(kFooterKey));

    //THE WHOLE REQUIREMENT, in one line: the scrollable stops where the
    //footer starts. Any overlap is content the user cannot reach.
    expect(scroll.bottom, lessThanOrEqualTo(footer.top + 0.5),
        reason: 'the scroll view runs under the footer by '
            '${scroll.bottom - footer.top} logical pixels');
  });

  testWidgets('and the footer is fully on screen', (tester) async {
    //a footer pushed off the bottom edge would "not overlap" while being
    //just as unusable
    await openProfile(
      tester,
      footer: Container(
        key: kFooterKey,
        height: kTallFooterHeight,
        color: const Color(0xFF123456),
      ),
    );

    final screen = tester.getRect(find.byType(MaterialApp));
    final footer = tester.getRect(find.byKey(kFooterKey));

    expect(footer.height, kTallFooterHeight);
    expect(footer.bottom, lessThanOrEqualTo(screen.bottom + 0.5));
  });

  testWidgets('without one, the profile uses the whole screen',
      (tester) async {
    //the fix must not leave a permanent gap at the bottom of every profile
    //opened from the deck
    await openProfile(tester);

    final screen = tester.getRect(find.byType(MaterialApp));
    final scroll = tester.getRect(find.byType(SingleChildScrollView));

    expect(scroll.bottom, closeTo(screen.bottom, 1));
    expect(find.byKey(kFooterKey), findsNothing);
  });
}
