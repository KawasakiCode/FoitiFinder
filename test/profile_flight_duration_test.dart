//How long the flight into a profile lasts, given where it started.
//
//THE COMPLAINT THIS CAME FROM. The hero flight had one duration whatever the
//distance, so a tile in the bottom row of the matches grid covered several
//times the travel of a top-row one in the same time - and therefore several
//times faster. The long flights snapped; nothing was wrong except the speed.
//
//WHAT IS BEING PINNED is that the speed is roughly constant, not that any
//particular tile gets any particular number of milliseconds. The reference
//values are free to be retuned; the relationship is not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/pages/main_pages/profile_detail_page.dart';

const Size kScreen = Size(400, 900);

Future<Duration> durationFor(WidgetTester tester, Rect? from) async {
  late Duration result;
  tester.view.physicalSize = kScreen * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          result = profileFlightDuration(context, from);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result;
}

//a tile of the usual grid size, with its top edge at [top]
Rect tileAt(double top) => Rect.fromLTWH(8, top, 190, 250);

void main() {
  testWidgets('further away takes longer', (tester) async {
    final near = await durationFor(tester, tileAt(120));
    final far = await durationFor(tester, tileAt(620));

    expect(far, greaterThan(near),
        reason: 'a tile further from the header must take longer, or it '
            'travels faster');
  });

  testWidgets('but not proportionally longer', (tester) async {
    //THE CORRECTION THIS TEST EXISTS FOR. Strict proportionality was the
    //first attempt and it was wrong: a top-row tile has barely a hundred
    //points to cover, so at constant speed it finished in a blink and read as
    //a cut. Duration has to grow with distance and grow LESS than it does.
    const destinationCentre = Offset(200, 900 * 0.55 / 2);

    final nearRect = tileAt(140);
    final farRect = tileAt(640);
    final distanceRatio = (farRect.center - destinationCentre).distance /
        (nearRect.center - destinationCentre).distance;

    final near = await durationFor(tester, nearRect);
    final far = await durationFor(tester, farRect);
    final durationRatio = far.inMilliseconds / near.inMilliseconds;

    expect(durationRatio, greaterThan(1),
        reason: 'further still has to take longer');
    expect(durationRatio, lessThan(distanceRatio),
        reason: 'distance x$distanceRatio but duration x$durationRatio - '
            'equal would be constant speed, which snaps on short flights');
  });

  testWidgets('even the shortest flight is a movement', (tester) async {
    //a tile sitting almost on the destination still has to animate, or the
    //page appears rather than arrives
    final onTopOfIt = Rect.fromCenter(
      center: const Offset(200, 900 * 0.55 / 2), width: 190, height: 250,
    );
    final duration = await durationFor(tester, onTopOfIt);

    expect(duration.inMilliseconds, greaterThanOrEqualTo(600));
  });

  testWidgets('and the longest is bounded', (tester) async {
    //far off the bottom of a tall screen: the curve saturates rather than
    //growing without limit, or a long list would produce a flight that
    //outlasts anybody's patience
    final duration = await durationFor(tester, tileAt(4000));
    expect(duration.inMilliseconds, lessThanOrEqualTo(900));
  });

  testWidgets('not knowing where it started is not an error', (tester) async {
    //the tile could not be measured - a sensible middling flight beats
    //refusing to animate
    final duration = await durationFor(tester, null);

    expect(duration.inMilliseconds, greaterThanOrEqualTo(600));
    expect(duration.inMilliseconds, lessThanOrEqualTo(900));
  });
}
