//One row of the bell.
//
//The server sends WHAT HAPPENED, not how to say it: there is no text in here,
//because the wording is translated in the app (see notifications_page.dart).
//A notification is a pointer plus a kind.

enum NotificationKind {
  //somebody matched with you and has already said yes - your answer is next
  matchWaiting,
  //you both said yes, so their Instagram is there to be read
  matchRevealed,
  //the person you were waiting on said no
  matchDeclined,
  //a kind written by a newer backend than this build: shown as a plain line
  //rather than hidden, so the list is never silently short
  unknown,
}

NotificationKind _kindFromJson(String? raw) => switch (raw) {
  'match' => NotificationKind.matchWaiting,
  'match_revealed' => NotificationKind.matchRevealed,
  'match_declined' => NotificationKind.matchDeclined,
  _ => NotificationKind.unknown,
};

class AppNotification {
  final int id;
  final NotificationKind kind;
  //NULL MEANS THERE IS NOTHING TO OPEN. A declined match is deleted, and the
  //notification about it outlives it on purpose - so a row with no matchId is
  //a statement, not a link.
  final int? matchId;
  final int? otherUserId;
  final String? otherName;
  final String? otherPhotoUrl;
  final DateTime createdAt;
  final bool read;
  //WHETHER THERE IS STILL SOMETHING TO DO, decided by the server from the
  //match this points at - not guessed here from the kind. "Someone is waiting
  //on your answer" stops being true the moment you answer, and this row does
  //not change when you do; inferring it in the app reopened a decision that
  //had already been made, with a decline button that then deleted a finished
  //match.
  final bool actionable;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.read,
    required this.actionable,
    this.matchId,
    this.otherUserId,
    this.otherName,
    this.otherPhotoUrl,
  });

  //the server says whether it leads anywhere; this only adds what the page
  //needs to actually open it
  bool get canOpen => actionable && matchId != null && otherUserId != null;

  AppNotification asRead() => AppNotification(
    id: id,
    kind: kind,
    matchId: matchId,
    otherUserId: otherUserId,
    otherName: otherName,
    otherPhotoUrl: otherPhotoUrl,
    createdAt: createdAt,
    read: true,
    actionable: actionable,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      kind: _kindFromJson(json['kind'] as String?),
      matchId: json['match_id'] as int?,
      otherUserId: json['other_user_id'] as int?,
      otherName: json['other_name'] as String?,
      otherPhotoUrl: json['other_photo_url'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      read: json['read'] as bool? ?? false,
      //absent from a backend older than this field: assume there is nothing
      //to open rather than offering a tap that lands on a stale page
      actionable: json['actionable'] as bool? ?? false,
    );
  }
}
