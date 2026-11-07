//One place errors go when nobody is looking.
//
//THE PROBLEM THIS SOLVES is the `catch (_) {}` that used to swallow a failed
//swipe: the user saw their card fly away and nothing happened, and no record
//of it existed anywhere. Some failures cannot be shown to the user (there is
//nothing useful to say about a retry that will probably succeed) but every
//one of them should be recorded SOMEWHERE.
//
//THAT SOMEWHERE IS NOW SENTRY, and until it was, it was the debug console -
//which only helps while a laptop is attached, because debugPrint is stripped
//from release builds. Every error in anybody else's hands was silent.
//
//A 422 from the swipe endpoint is the example worth alerting on. It cannot
//happen by accident - the server validates the action against a fixed list -
//so if one ever arrives it means a build in somebody's hands is sending
//something the server rejects, and the queue deliberately will not retry it.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Record an error that the user is not being shown.
///
/// SAFE WITHOUT SENTRY. `Sentry.captureException` on an uninitialised hub is a
/// no-op rather than a throw, so this works in tests, in CI and in a debug
/// build with no DSN - and the debugPrint stays, because while developing the
/// console is where you are actually looking.
void reportError(Object error, {StackTrace? stack, String? context}) {
  debugPrint('[error${context == null ? '' : ' in $context'}] $error');
  if (stack != null) debugPrint('$stack');

  Sentry.captureException(
    error,
    stackTrace: stack,
    //WHERE IT CAME FROM, as a tag rather than in the message, so that
    //'swipe rejected by server' groups as one issue however the exception
    //underneath it is worded.
    withScope: context == null
        ? null
        : (scope) => scope.setTag('operation', context),
  );
}

/// Catch the errors nobody wrapped in a try.
///
/// THE REASON THIS EXISTS. reportError has three call sites, which are three
/// places somebody remembered to catch something. The crashes worth hearing
/// about are the ones nobody predicted, and those arrive through two hooks
/// that were not set at all:
///
///   FlutterError.onError          anything thrown inside the framework -
///                                 every build, layout and paint error
///   PlatformDispatcher.onError    uncaught asynchronous errors, which is
///                                 most of them in an app that awaits a
///                                 network call on every screen
///
/// Without these, an exception in a build method printed a red screen in
/// debug and vanished in release.
void installErrorHandlers() {
  final flutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    //STILL CALL THE ORIGINAL. It is what prints the red screen and the
    //console dump in debug; replacing it outright would make a framework
    //error harder to see while developing, which is the opposite of the
    //point.
    flutterOnError?.call(details);
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    reportError(error, stack: stack, context: 'uncaught async');
    //TRUE MEANS HANDLED, which stops the error reaching the platform and
    //killing the isolate. An unhandled future in one screen must not take
    //the app down.
    return true;
  };
}

/// Run [app] with Sentry watching, if there is a DSN to send to.
///
/// THE DSN IS A COMPILE-TIME DEFINE, the same way API_BASE_URL is:
///
///     flutter build appbundle --release --dart-define=SENTRY_DSN=https://...
///
/// NO DSN MEANS NO SENTRY, and that is the normal state for a debug build.
/// Nothing is sent, nothing is initialised, and the app runs exactly as it
/// did before - so a contributor without the secret is not blocked, and CI
/// does not need it either.
///
/// A DSN IS NOT A SECRET in the way an API key is - it only permits writing
/// events into one project - but it is kept out of the repo anyway, because a
/// public one is an invitation to fill somebody's error quota with noise.
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

      //WHICH BUILD AN ERROR CAME FROM. Without this every report is attributed
      //to "unknown" and a fix cannot be told apart from a regression.
      options.release = release;
      options.environment = kDebugMode ? 'debug' : 'production';

      //=================================================================
      //WHAT IS DELIBERATELY NOT SENT. The privacy statement describes this
      //section, so changing anything here changes a published document.
      //=================================================================

      //NO PERSONAL DATA BY DEFAULT: no IP address, no device name, no user.
      options.sendDefaultPii = false;

      //NO SCREENSHOTS AND NO WIDGET TREE. Both are on by default in some
      //configurations and both are catastrophic here: a screenshot of this
      //app is somebody's face, their bio, or an Instagram handle that was
      //just revealed to one person and must not reach anybody else.
      options.attachScreenshot = false;
      //ignore on an experimental setter rather than leaving it at its
      //default: the default is already false, but this is a promise in a
      //published privacy statement and it should be visible in the code that
      //makes it, not inferred from an SDK's defaults.
      // ignore: experimental_member_use
      options.attachViewHierarchy = false;

      //NO PERFORMANCE MONITORING. It would make the "no analytics" promise in
      //the privacy statement false, and it is the thing that burns a free
      //quota fastest.
      options.tracesSampleRate = 0.0;

      //BREADCRUMBS, BUT NOT THE AUTOMATIC USER ONES. The default set records
      //taps and navigation, which is a behavioural trail rather than a
      //diagnostic one.
      options.enableUserInteractionBreadcrumbs = false;
      options.enableAutoNativeBreadcrumbs = true;

      options.beforeSend = _scrub;
    },
    appRunner: () async {
      installErrorHandlers();
      await app();
    },
  );
}

const String _dsn = String.fromEnvironment('SENTRY_DSN');

//EVERY EVENT IS ATTRIBUTED TO THIS AND NOTHING ELSE.
//
//NOT null, FOR TWO REASONS. copyWith below cannot clear a field - it is
//`user ?? this.user`, so passing null silently keeps whatever was there,
//which is how a scrubber ends up doing nothing at all. And SentryUser asserts
//that it carries at least one of id/username/email/ipAddress, so an empty one
//is not constructible.
//
//Overwriting with a constant turns out to be the stronger guarantee anyway:
//clearing the field would still let a later `scope.setUser(...)` anywhere in
//the app put a real uid back, and this cannot.
final _anonymous = SentryUser(id: 'anonymous');

//THE LAST GATE BEFORE ANYTHING LEAVES THE DEVICE.
//
//A stack trace carries whatever was in scope, and in this app that can be a
//bio, a name, or - once - an Instagram handle. Nothing here can read a stack
//frame's locals, so this is not a guarantee about the trace; what it does is
//refuse the fields Sentry attaches deliberately.
SentryEvent? _scrub(SentryEvent event, Hint hint) {
  return event.copyWith(
    //NO IDENTITY ON ANY REPORT. An error says what broke, not who it broke
    //for - and the Firebase uid is the one value that joins every table in
    //this system to a person.
    user: _anonymous,
    //THE QUERY STRING IS DROPPED, and it is not idle tidying: /users/feed
    //now sends `exclude`, which is a list of every candidate the deck was
    //holding, and other paths carry a match id. Rebuilt rather than edited,
    //so headers, cookies and body go with it. The path alone is what
    //identifies the endpoint, which is all a stack trace needs.
    request: event.request == null
        ? null
        : SentryRequest(
            url: event.request!.url?.split('?').first,
            method: event.request!.method,
          ),
  );
}
