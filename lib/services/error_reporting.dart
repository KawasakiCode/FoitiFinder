//One place errors go when nobody is looking.
//
//THE PROBLEM THIS SOLVES is the `catch (_) {}` that used to swallow a failed
//swipe: the user saw their card fly away and nothing happened, and no record
//of it existed anywhere. Some failures cannot be shown to the user (there is
//nothing useful to say about a retry that will probably succeed) but every
//one of them should be recorded SOMEWHERE.
//
//Right now that somewhere is the debug console, which only helps while a
//laptop is attached. The point of the seam is that wiring a real service in
//is one line here rather than a hunt through every catch block:
//
//    await Sentry.captureException(error, stackTrace: stack);
//
//A 422 from the swipe endpoint is the example worth alerting on. It cannot
//happen by accident - the server validates the action against a fixed list -
//so if one ever arrives it means a build in somebody's hands is sending
//something the server rejects, and the queue deliberately will not retry it.

import 'package:flutter/foundation.dart';

void reportError(Object error, {StackTrace? stack, String? context}) {
  //TODO: Sentry.captureException goes here. Until then, at least say it out
  //loud rather than dropping it: debugPrint is stripped from release builds,
  //so this costs nothing in production and everything is still visible while
  //developing.
  debugPrint('[error${context == null ? '' : ' in $context'}] $error');
  if (stack != null) debugPrint('$stack');
}
