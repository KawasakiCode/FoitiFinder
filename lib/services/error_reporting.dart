//Errors the user is never shown still have to be recorded somewhere, and in
//release that somewhere is Sentry.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Record an error that is not being surfaced to the user.
///
/// Safe without Sentry: `captureException` on an uninitialised hub is a no-op
/// rather than a throw, so this works in tests, in CI and in any build with
/// no DSN.
void reportError(Object error, {StackTrace? stack, String? context}) {
  Sentry.captureException(
    error,
    stackTrace: stack,
    //the origin goes on a tag rather than into the message, so that
    //'swipe rejected by server' groups as one issue however the exception
    //underneath it happens to be worded
    withScope: context == null
        ? null
        : (scope) => scope.setTag('operation', context),
  );
}

/// Route the errors nobody wrapped in a try into Sentry.
///
/// Two hooks carry everything unpredicted:
///
///   FlutterError.onError          anything thrown inside the framework -
///                                 every build, layout and paint error
///   PlatformDispatcher.onError    uncaught asynchronous errors, which is
///                                 most of them in an app that awaits a
///                                 network call on every screen
void installErrorHandlers() {
  final flutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    //still call the original: it is what prints the red screen and the
    //console dump while developing
    flutterOnError?.call(details);
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    reportError(error, stack: stack, context: 'uncaught async');
    //true means handled, which stops the error reaching the platform and
    //killing the isolate - an unhandled future on one screen must not take
    //the app down
    return true;
  };
}

/// Run [app] with Sentry watching, if there is a DSN to send to.
///
/// The DSN is a compile-time define, the same way API_BASE_URL is:
///
///     flutter build appbundle --release --dart-define=SENTRY_DSN=https://...
///
/// No DSN means no Sentry: nothing is sent, nothing is initialised, and the
/// app runs exactly as it otherwise would, so a contributor without the
/// secret is not blocked and CI does not need one either.
Future<void> runWithErrorReporting(
  FutureOr<void> Function() app, {
  String? release,
}) async {
  if (_dsn.isEmpty) {
    installErrorHandlers();
    await app();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _dsn;

      //which build an error came from; without this every report is
      //attributed to "unknown" and a fix cannot be told apart from a
      //regression
      options.release = release;
      options.environment = kDebugMode ? 'debug' : 'production';

      //=================================================================
      //WHAT IS DELIBERATELY NOT SENT. The privacy statement describes this
      //section, so changing anything here changes a published document.
      //=================================================================

      //no IP address, no device name, no user
      options.sendDefaultPii = false;

      //no screenshots and no widget tree: a screenshot of this app is
      //somebody's face, their bio, or an Instagram handle that was just
      //revealed to one person and must not reach anybody else
      options.attachScreenshot = false;
      //set explicitly rather than left at its default, because this is a
      //promise in a published document and should be visible in the code
      //that makes it
      // ignore: experimental_member_use
      options.attachViewHierarchy = false;

      //performance monitoring would make the "no analytics" promise false,
      //and it is what burns a free quota fastest
      options.tracesSampleRate = 0.0;

      //the default breadcrumb set records taps and navigation, which is a
      //behavioural trail rather than a diagnostic one
      options.enableUserInteractionBreadcrumbs = false;
      options.enableAutoNativeBreadcrumbs = true;

      options.beforeSend = scrubEvent;
    },
    appRunner: () async {
      installErrorHandlers();
      await app();
    },
  );
}

const String _dsn = String.fromEnvironment('SENTRY_DSN');

//Every event is attributed to this and nothing else.
//
//Not null, for two reasons. copyWith below cannot clear a field - it is
//`user ?? this.user`, so passing null silently keeps whatever was there. And
//SentryUser asserts it carries at least one of id/username/email/ipAddress,
//so an empty one is not constructible.
//
//Overwriting with a constant is the stronger guarantee anyway: clearing the
//field would still let a later scope.setUser() anywhere in the app put a real
//uid back, and this cannot.
final _anonymous = SentryUser(id: 'anonymous');

//The last gate before anything leaves the device.
//
//A stack trace carries whatever was in scope, and in this app that can be a
//bio, a name or an Instagram handle. Nothing here can read a stack frame's
//locals, so this is not a guarantee about the trace; what it does is refuse
//the fields Sentry attaches deliberately.
@visibleForTesting
SentryEvent? scrubEvent(SentryEvent event, Hint hint) {
  return event.copyWith(
    //an error says what broke, not who it broke for - and the Firebase uid is
    //the one value that joins every table in this system to a person
    user: _anonymous,
    //the query string is dropped: /users/feed sends `exclude`, a list of
    //every candidate the deck was holding, and other paths carry a match id.
    //Rebuilt rather than edited, so headers, cookies and body go with it.
    request: event.request == null
        ? null
        : SentryRequest(
            url: event.request!.url?.split('?').first,
            method: event.request!.method,
          ),
  );
}
