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

  const AppNotification({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.read,
    this.matchId,
    this.otherUserId,
    this.otherName,
    this.otherPhotoUrl,
  });

  //only a kind that points at something still alive can be tapped through
  bool get isActionable => matchId != null && otherUserId != null &&
      (kind == NotificationKind.matchWaiting ||
          kind == NotificationKind.matchRevealed);

  AppNotification asRead() => AppNotification(
    id: id,
    kind: kind,
    matchId: matchId,
    otherUserId: otherUserId,
    otherName: otherName,
    otherPhotoUrl: otherPhotoUrl,
    createdAt: createdAt,
    read: true,
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
    );
  }
}
