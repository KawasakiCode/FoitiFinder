//The star on a card: the only interest the deck is allowed to disclose.
//
//WHAT IS WORTH PINNING is the rule, not the icon. A plain like must stay
//invisible - the deck's whole privacy model is that you cannot tell who likes
//you - and a super like is the one exception, opted into by the sender when
//they spend one of two a week. A badge that appeared on the wrong cards would
//quietly give away everybody's likes.
//
//AND THAT IT EXPLAINS ITSELF. A blue star means nothing to somebody seeing it
//for the first time, and the one moment they will try to find out is when it
//is in front of them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/card_data_model.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/photo_card.dart';

//NOT find.byIcon(Icons.star): the card carries a second star, on the super
//like BUTTON, and an icon finder cannot tell the badge from the button.
final badge = find.byKey(const ValueKey(kSuperLikeBadgeKey));

CardData card({bool superLikedYou = false}) => CardData(
      id: 2,
      name: 'Katerina',
      bio: 'Probably at the library.',
      age: 21,
      superLikedYou: superLikedYou,
    );

Future<void> pumpCard(WidgetTester tester, CardData data) async {
  tester.view.physicalSize = const Size(1320, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PhotoCard(card: data)),
    ),
  );
  await tester.pump();
}

void main() {
  buttonTests();

  testWidgets('no badge on an ordinary card', (tester) async {
    //A PLAIN LIKE IS INVISIBLE and this is where that would leak: the server
    //sends super_liked_you and nothing else about who wants whom.
    await pumpCard(tester, card());
    expect(badge, findsNothing);
  });

  testWidgets('a star when they super liked you', (tester) async {
    await pumpCard(tester, card(superLikedYou: true));
    expect(badge, findsOneWidget);
  });

  testWidgets('tapping it says what it means, and who', (tester) async {
    await pumpCard(tester, card(superLikedYou: true));

    await tester.tap(badge);
    await tester.pumpAndSettle();

    expect(find.text('Katerina super liked you'), findsOneWidget);
    //the scarcity is the point: it is what makes the badge worth anything
    expect(find.textContaining('two of these a week'), findsOneWidget);
  });

  testWidgets('the star does not open the profile', (tester) async {
    //it sits above the tap-anywhere layer, so its own tap has to win -
    //otherwise the explanation is unreachable and the badge stays a mystery
    var opened = false;
    tester.view.physicalSize = const Size(1320, 2700);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PhotoCard(
            card: card(superLikedYou: true),
            onOpen: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(badge);
    await tester.pumpAndSettle();

    expect(opened, isFalse);
    expect(find.text('Katerina super liked you'), findsOneWidget);
  });
}

Gradient starGradient(WidgetTester tester) {
  //the star on the ACTION ROW, not the badge: the badge is keyed, this one is
  //found by being the star inside a SwipeActionButton
  final button = tester.widget<SwipeActionButton>(
    find.byWidgetPredicate(
      (w) => w is SwipeActionButton && w.icon == Icons.star,
    ),
  );
  return button.gradient;
}

//The button that sends one, when there are none left to send.
//
//GREY RATHER THAN GONE. A button that disappears leaves people wondering what
//used to be there; a grey one says "this exists and you have none" - and it
//stays pressable on purpose, because the tap is the only thing that explains
//why.
void buttonTests() {
  testWidgets('the star is blue while you still have some', (tester) async {
    await pumpCard(tester, card());
    expect(starGradient(tester), AppColors.superLikeGradient);
  });

  testWidgets('and grey once the week is spent', (tester) async {
    tester.view.physicalSize = const Size(1320, 2700);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PhotoCard(card: card(), superLikeAvailable: false),
        ),
      ),
    );
    await tester.pump();

    expect(starGradient(tester), AppColors.spentGradient);
  });
}
