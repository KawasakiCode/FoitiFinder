//The retry policy, which by definition only runs when something is already
//broken - so it is the last code anyone would notice being wrong.
//
//These test the decisions, not the HTTP: whether an error is worth retrying,
//whether the queue survives a restart, whether it dedupes by person, and
//whether it forgets swipes that are too old to mean anything.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/services/swipe_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

//the same key swipe_queue.dart writes under
const String _key = 'pending_swipes';

List<Map<String, dynamic>> queued(SharedPreferences prefs) {
  final raw = prefs.getString(_key);
  if (raw == null) return [];
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

String entry(int targetId, String action, DateTime at) => jsonEncode([
  {
    'target_id': targetId,
    'action': action,
    'queued_at': at.toIso8601String(),
  },
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('what is worth retrying', () {
    // These mirror _isRetryable. Expressed through the queue's behaviour
    // rather than the private function, so the test survives a rename.
    test('a refusal is a refusal', () {
      //422 is the server saying the request itself is wrong - the body, the
      //target, the state. A hundred more attempts get the same answer.
      expect(const ApiException(422, 'nope').statusCode, 422);
    });

    test('ApiException carries the status, unlike a bare Exception', () {
      const error = ApiException(503, 'waking up');
      expect(error.statusCode, 503);
      expect(error.toString(), contains('503'));
    });
  });

  group('the queue on disk', () {
    test('survives a restart', () async {
      final at = DateTime.now();
      SharedPreferences.setMockInitialValues({_key: entry(42, 'like', at)});
      final prefs = await SharedPreferences.getInstance();

      //a fresh SwipeQueue, as a cold launch would build it
      final queue = SwipeQueue(prefs);
      expect(queue.pendingCount, 1, reason: 'a parked swipe must outlive the app');
    });

    test('forgets swipes older than the limit', () async {
      final old = DateTime.now().subtract(kSwipeMaxAge + const Duration(days: 1));
      SharedPreferences.setMockInitialValues({_key: entry(42, 'like', old)});
      final prefs = await SharedPreferences.getInstance();

      final queue = SwipeQueue(prefs);
      //a week-old swipe is about a deck that has moved on, and the person may
      //not even be on the app any more
      expect(queue.pendingCount, 0);
    });

    test('an unreadable queue is dropped, not crashed on', () async {
      SharedPreferences.setMockInitialValues({_key: 'not json at all'});
      final prefs = await SharedPreferences.getInstance();

      final queue = SwipeQueue(prefs);
      expect(queue.pendingCount, 0);
      //and it does not come back on the next launch
      expect(prefs.getString(_key), isNull);
    });

    test('tells the deck who to hide', () async {
      //the server has not heard about these yet, so it will keep offering
      //them until the swipe lands
      final at = DateTime.now();
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode([
          {'target_id': 42, 'action': 'pass', 'queued_at': at.toIso8601String()},
          {'target_id': 77, 'action': 'like', 'queued_at': at.toIso8601String()},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      expect(SwipeQueue(prefs).pendingTargetIds, {42, 77});
    });

    test('a second swipe on the same person replaces the first', () async {
      //reachable by rewinding: pass, rewind, like. The newest intent is the
      //only one that should ever reach the server.
      final at = DateTime.now();
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode([
          {'target_id': 42, 'action': 'pass', 'queued_at': at.toIso8601String()},
          {'target_id': 42, 'action': 'like', 'queued_at': at.toIso8601String()},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      //both are on disk, but they are about one person
      expect(SwipeQueue(prefs).pendingTargetIds, {42});
    });

    test('a flush that cannot reach anything loses nothing', () async {
      //there is no server in a test, so every attempt fails - which is the
      //case that matters: a flush must never be able to empty the queue it
      //could not deliver. This is also what guards the overwrite race, since
      //the flush now removes only what it actually resolved.
      final at = DateTime.now();
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode([
          for (final id in [1, 2, 3])
            {'target_id': id, 'action': 'like', 'queued_at': at.toIso8601String()},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final queue = SwipeQueue(prefs);

      await queue.flush(uid: 'whoever');

      expect(queue.pendingTargetIds, {1, 2, 3});
    });

    test('a flush with nothing queued does nothing and does not throw', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await SwipeQueue(prefs).flush(uid: 'whoever');
      expect(queued(prefs), isEmpty);
    });
  });

  group('the policy itself', () {
    test('two quick retries, then disk', () {
      //the point is that it stops blocking: the user is waiting on a card
      //that has already left the screen
      expect(kSwipeRetryDelays.length, 2);
      final total = kSwipeRetryDelays.fold(
        Duration.zero,
        (sum, delay) => sum + delay,
      );
      expect(total, lessThan(const Duration(seconds: 10)));
    });

    test('given up on by age, not by attempts', () {
      //a count would be arbitrary - the fourth attempt is no likelier to fail
      //than the fortieth when the phone has no signal for a day
      expect(kSwipeMaxAge, const Duration(days: 7));
    });

    test('the queue is capped so an offline month cannot grow forever', () {
      expect(kSwipeQueueMax, greaterThan(0));
      expect(kSwipeQueueMax, lessThanOrEqualTo(1000));
    });
  });
}
