//A swipe that does not reach the server is a match that never happens.
//
//THE DECK ANIMATES FIRST AND REGISTERS AFTER, which is right - a card must
//never wait on the network - but it means a failed request has no card left to
//put back. By the time a timeout returns, the user has swiped past two more
//people, so "return it to the top" shows a profile they already dismissed
//reappearing out of order. The swipe has to be delivered instead.
//
//HOW MANY TIMES DO WE RETRY? Not a number: a count is the wrong knob, because
//the fourth attempt is no more likely to fail than the fortieth if the cause
//is "this phone has had no signal since Tuesday". Three rules instead:
//
//  1. ONLY RETRY WHAT RETRYING CAN FIX. A network error, a timeout, a 5xx, a
//     429 or a 401 (the token may simply have expired, and the next attempt
//     fetches a fresh one). Any other 4xx is the server rejecting the
//     request - the target does not exist, the body is wrong - and the
//     hundredth attempt gets the same answer. Dropped immediately.
//  2. TWO QUICK RETRIES, then stop blocking. Covers a blip and most of a
//     Render cold start. Beyond that the user is waiting for nothing.
//  3. THEN IT GOES TO DISK and is retried on EVENTS, never on a timer: app
//     launch, app resume, and after any swipe that succeeds (which is proof
//     the network is back). It is given up on by AGE, not by attempts - a
//     swipe older than kSwipeMaxAge is about a deck that has moved on.
//
//RETRYING IS SAFE BECAUSE THE SERVER IS IDEMPOTENT. record_swipe looks up the
//existing swipe for that target and only writes when the action changed, so
//the same swipe sent ten times is one row. The notifications it can produce
//are guarded the same way (see _notify's `once`). Without that, a retry queue
//would be a duplicate-match generator.

import 'dart:async';
import 'dart:convert';

import 'package:foitifinder/models/match_models.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/services/error_reporting.dart';
import 'package:shared_preferences/shared_preferences.dart';

//Two retries before the swipe is parked on disk: enough for a dropped packet
//or a server waking up, short enough that nobody is left staring at a screen
//that has already moved on.
const List<Duration> kSwipeRetryDelays = [
  Duration(seconds: 1),
  Duration(seconds: 4),
];

//A swipe nobody managed to deliver in a week is about a deck that has long
//moved on, and the person may not even be on the app any more. Dropped rather
//than kept forever.
const Duration kSwipeMaxAge = Duration(days: 7);

//A cap so a device that has been offline for a month does not accumulate an
//unbounded queue. The oldest go first - the newest swipes are the ones whose
//outcome the user might still be waiting for.
const int kSwipeQueueMax = 200;

const String _kQueueKey = 'pending_swipes';

class _PendingSwipe {
  final int targetId;
  final String action;
  final DateTime queuedAt;

  const _PendingSwipe({
    required this.targetId,
    required this.action,
    required this.queuedAt,
  });

  bool get isStale => DateTime.now().difference(queuedAt) > kSwipeMaxAge;

  //Identifies this exact entry, not just the person it is about. A flush
  //removes what it delivered BY IDENTITY, because by the time it finishes the
  //list on disk may not be the one it started with.
  String get id => '$targetId@${queuedAt.microsecondsSinceEpoch}';

  Map<String, dynamic> toJson() => {
    'target_id': targetId,
    'action': action,
    'queued_at': queuedAt.toIso8601String(),
  };

  static _PendingSwipe? fromJson(Map<String, dynamic> json) {
    final targetId = json['target_id'];
    final action = json['action'];
    if (targetId is! int || action is! String) return null;
    return _PendingSwipe(
      targetId: targetId,
      action: action,
      queuedAt:
          DateTime.tryParse(json['queued_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class SwipeQueue {
  final SharedPreferences _prefs;

  SwipeQueue(this._prefs);

  //Set up once in main(), where prefs already exists. A plain singleton rather
  //than a provider because nothing rebuilds when it changes - it is plumbing,
  //not state.
  static SwipeQueue? _instance;
  static SwipeQueue get instance {
    assert(_instance != null, 'SwipeQueue.init must run before any swipe');
    return _instance!;
  }

  static void init(SharedPreferences prefs) => _instance = SwipeQueue(prefs);

  bool _flushing = false;

  /// Send a swipe, retrying what is worth retrying and parking the rest.
  ///
  /// Returns what the server said, or [SwipeResult.none] when the swipe has
  /// been queued - the caller cannot know yet whether it was a match, so a
  /// match made by a queued swipe is never celebrated. It is found later, on
  /// the matches page, which reloads whenever that tab is opened.
  ///
  /// record_swipe USED TO leave the swiper a notification for exactly this
  /// case; that row is gone along with the rest of the in-app match
  /// notifications, and the matches page replaced it.
  Future<SwipeResult> send({
    required String uid,
    required int targetId,
    required String action,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final result = await ApiService.registerSwipe(uid, targetId, action);
        //a success is proof the network is back, so anything parked earlier
        //gets another go - not awaited, because this caller is done
        unawaited(flush(uid: uid));
        return result;
      } catch (error) {
        if (!_isRetryable(error)) {
          //THE SERVER WILL NOT CHANGE ITS MIND, so queueing it would mean
          //retrying something impossible on every launch forever. It is also
          //the one failure here that should never happen in a shipped build:
          //the action is validated against a fixed list, so a rejection means
          //a client is sending something wrong and somebody needs to know.
          reportError(error, context: 'swipe rejected by server');
          return SwipeResult.none;
        }
        if (attempt >= kSwipeRetryDelays.length) {
          await _enqueue(targetId, action);
          return SwipeResult.none;
        }
        await Future.delayed(kSwipeRetryDelays[attempt]);
      }
    }
  }

  /// Try to deliver everything parked on disk. Safe to call at any time.
  Future<void> flush({required String uid}) async {
    if (_flushing) return;
    _flushing = true;
    try {
      final pending = _read();
      if (pending.isEmpty) return;

      //WHAT THIS FLUSH FINISHED WITH, by identity. Not "what to keep": a
      //flush of twenty swipes spends seconds inside those awaits, and the
      //user can swipe - and fail, and enqueue - the whole time. Writing back
      //the list this loop started from would erase anything added since,
      //which is the exact failure the queue exists to prevent.
      final done = <String>{};
      for (final swipe in pending) {
        try {
          await ApiService.registerSwipe(uid, swipe.targetId, swipe.action);
          done.add(swipe.id);
        } catch (error) {
          if (!_isRetryable(error)) {
            //refused on the merits: retrying it on every launch forever would
            //be worse than dropping it
            done.add(swipe.id);
            continue;
          }
          //STOP AT THE FIRST ONE THAT CANNOT GET THROUGH. The first attempt
          //is the connectivity test, and if it failed the rest fail the same
          //way - twenty entries against a dead network is twenty timeouts,
          //four minutes of pointless waiting, and a flush still running when
          //the user comes back. The rest stay for the next launch or resume.
          break;
        }
      }

      if (done.isEmpty) return;
      //RE-READ, because this is a different moment than the one the loop
      //began in. Only the entries this flush actually resolved are removed;
      //everything else - including swipes queued while it ran - survives.
      final current = _read();
      await _write(
        current.where((swipe) => !done.contains(swipe.id)).toList(),
      );
    } finally {
      _flushing = false;
    }
  }

  int get pendingCount => _read().length;

  /// Who has an undelivered swipe waiting.
  ///
  /// THE DECK FILTERS ON THIS. The server does not know about a queued swipe,
  /// so it will keep offering that person - someone you passed reappears, or
  /// worse, someone you already liked comes round again and you pass on them
  /// second time. Until the swipe lands, this app is the only thing that
  /// knows it happened.
  Set<int> get pendingTargetIds => {for (final swipe in _read()) swipe.targetId};

  //KEYED BY TARGET, so this is a map and not a log. A second swipe on the same
  //person replaces the first (only reachable by rewinding), which removes the
  //whole question of applying them in order.
  Future<void> _enqueue(int targetId, String action) async {
    final pending = _read()..removeWhere((s) => s.targetId == targetId);
    pending.add(
      _PendingSwipe(
        targetId: targetId,
        action: action,
        queuedAt: DateTime.now(),
      ),
    );
    await _write(pending);
  }

  List<_PendingSwipe> _read() {
    final raw = _prefs.getString(_kQueueKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>)
            //STALE ENTRIES ARE GONE AS SOON AS THEY ARE READ, not when the
            //next write happens: everything downstream - the count, the
            //flush - should see the same list, and a swipe past its age is
            //not pending, it is forgotten.
            ?switch (_PendingSwipe.fromJson(item)) {
              final swipe? when !swipe.isStale => swipe,
              _ => null,
            },
      ];
    } catch (_) {
      //unreadable queue: drop it rather than crash on every launch forever
      _prefs.remove(_kQueueKey);
      return [];
    }
  }

  Future<void> _write(List<_PendingSwipe> pending) async {
    final fresh = pending.where((s) => !s.isStale).toList();
    //oldest first out when over the cap: the newest swipes are the ones whose
    //outcome someone may still be waiting on
    final capped = fresh.length > kSwipeQueueMax
        ? fresh.sublist(fresh.length - kSwipeQueueMax)
        : fresh;
    if (capped.isEmpty) {
      await _prefs.remove(_kQueueKey);
      return;
    }
    await _prefs.setString(
      _kQueueKey,
      jsonEncode([for (final swipe in capped) swipe.toJson()]),
    );
  }
}

/// Whether another attempt could possibly produce a different answer.
bool _isRetryable(Object error) {
  if (error is ApiException) {
    final code = error.statusCode;
    //401: the ID token had probably expired, and getIdToken() fetches a fresh
    //one on the next attempt. 408/429/5xx: the server is asking us to come
    //back later.
    if (code == 401 || code == 408 || code == 429 || code >= 500) return true;
    //every other 4xx is a refusal on the merits
    return false;
  }
  //SocketException, TimeoutException, HandshakeException, a dropped
  //connection: all of them are "the request did not arrive", and all of them
  //are worth another go.
  return true;
}
