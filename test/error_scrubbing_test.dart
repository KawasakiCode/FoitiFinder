//What an error report is not allowed to carry off the phone.
//
//WHY THIS FILE EXISTS, AND WHY IT EXISTS LATE. The backend's equivalent had 27
//tests and the Dart side had none, which is how a credential ended up in every
//server-side report: sentry-sdk sends stack frame locals by default, every
//ASGI frame holds the whole request, and the only reason anybody noticed was a
//test that went through the real integration. Dart cannot read frame locals so
//that particular leak has no counterpart here - but this is the same class of
//code, doing the same two jobs, and the asymmetry in coverage was the part
//worth fixing.
//
//THE TWO JOBS. Overwrite the user, and rebuild the request without its query
//string. Both are promises in a published privacy statement: section 2 says a
//report carries no identity and nothing you had typed, and section 8 names
//Sentry as the processor that receives it. Widening either is a change to that
//document.

import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/services/error_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

SentryEvent scrub(SentryEvent event) => scrubEvent(event, Hint())!;

void main() {
  group('who the error is attributed to', () {
    test('a real identity is overwritten', () {
      //the Firebase uid is the one value that joins every table in this
      //system to a person
      final event = scrub(SentryEvent(
        user: SentryUser(
          id: 'firebase-uid-of-a-real-person',
          email: 'someone@uoa.gr',
          ipAddress: '1.2.3.4',
        ),
      ));

      expect(event.user?.id, 'anonymous');
      expect(event.user?.email, isNull);
      expect(event.user?.ipAddress, isNull);
    });

    test('and an event with no user gets one anyway', () {
      //OVERWRITTEN, NOT CLEARED, and the difference is the point. copyWith on
      //a SentryEvent is `user ?? this.user`, so passing null keeps whatever
      //was there - a scrubber written the obvious way does nothing at all.
      //Overwriting also means a setUser anywhere else in the app cannot put a
      //real uid back, because this function has the last word.
      final event = scrub(SentryEvent());

      expect(event.user?.id, 'anonymous');
    });

    test('nothing identifying survives in the serialised event', () {
      //the assertions above read named fields; this one reads everything,
      //because the field that leaks is the one nobody thought to name
      final event = scrub(SentryEvent(
        user: SentryUser(id: 'uid-abc-123', username: 'maria'),
      ));

      expect(event.toJson().toString(), isNot(contains('uid-abc-123')));
      expect(event.toJson().toString(), isNot(contains('maria')));
    });
  });

  group('the request', () {
    test('loses its query string', () {
      final event = scrub(SentryEvent(
        request: SentryRequest(
          url: 'https://api.example.org/users/feed?limit=20&exclude=11,12,13',
          method: 'GET',
        ),
      ));

      expect(event.request?.url, 'https://api.example.org/users/feed');
    });

    test('and that matters most for the feed', () {
      //THE REASON THIS IS NOT IDLE TIDYING. /users/feed?exclude=... is the
      //list of everybody the deck was holding - added for a good reason by
      //the paging fix, and it turned a harmless URL into a record of who one
      //person was being shown.
      final event = scrub(SentryEvent(
        request: SentryRequest(
          url: 'https://api.example.org/users/feed?exclude=11,12,13',
        ),
      ));

      expect(event.request!.url, isNot(contains('exclude')));
      expect(event.toJson().toString(), isNot(contains('11,12,13')));
    });

    test('keeps the path, because that is what identifies the endpoint', () {
      final event = scrub(SentryEvent(
        request: SentryRequest(
          url: 'https://api.example.org/matches/41/confirm',
          method: 'POST',
        ),
      ));

      expect(event.request?.url, endsWith('/matches/41/confirm'));
      expect(event.request?.method, 'POST');
    });

    test('is rebuilt, so everything else on it goes too', () {
      //REBUILT RATHER THAN EDITED, deliberately. A SentryRequest also carries
      //headers, cookies, a body and a separate queryString - and editing the
      //url alone would leave all four untouched. Constructing a new one with
      //two fields is what drops them, and it is why this test asserts on
      //fields the scrub never mentions.
      final event = scrub(SentryEvent(
        request: SentryRequest(
          url: 'https://api.example.org/users/me?token=leak',
          method: 'PATCH',
          queryString: 'token=leak',
          cookies: 'session=abc',
          headers: const {'Authorization': 'Bearer A-REAL-TOKEN'},
          data: const {'bio': 'something personal'},
        ),
      ));

      final json = event.toJson().toString();
      expect(json, isNot(contains('A-REAL-TOKEN')));
      expect(json, isNot(contains('something personal')));
      expect(json, isNot(contains('session=abc')));
      expect(json, isNot(contains('leak')));
      expect(event.request?.method, 'PATCH');
    });

    test('an event with no request stays without one', () {
      //a crash on a screen that made no network call - must not throw
      final event = scrub(SentryEvent());

      expect(event.request, isNull);
    });

    test('a request with no url is not an error', () {
      final event = scrub(SentryEvent(request: SentryRequest(method: 'GET')));

      expect(event.request?.url, isNull);
      expect(event.request?.method, 'GET');
    });
  });

  group('what it leaves alone', () {
    test('the exception itself, which is the whole point of the report', () {
      final event = scrub(SentryEvent(
        throwable: StateError('the deck could not be refilled'),
      ));

      expect(event.throwable, isA<StateError>());
      expect(event.throwable.toString(), contains('could not be refilled'));
    });

    test('the release and environment, which say which build broke', () {
      final event = scrub(SentryEvent(
        release: 'com.foitifinder.app@1.0.0+1',
        environment: 'production',
      ));

      expect(event.release, 'com.foitifinder.app@1.0.0+1');
      expect(event.environment, 'production');
    });

    test('and it never drops the event', () {
      //RETURNING null WOULD DISCARD THE REPORT, silently, which is the one
      //failure worse than sending too much: it looks exactly like an app that
      //never crashes. Every case above returns an event; this says so for the
      //emptiest possible one.
      expect(scrubEvent(SentryEvent(), Hint()), isNotNull);
    });
  });
}
