#Push notifications, and the two moments worth sending one.
#
#A MATCH IS THE ONLY THING ANNOUNCED. There used to be a 'like' push, which
#made sense while a likes page existed to open: the notification led
#somewhere. That page is gone and likers go back into the deck unannounced,
#so "someone liked you" became a ping with nothing on the other end of the
#tap - you cannot find them, you can only swipe and hope. It was also the
#most frequent push in the app by a wide margin, and on Android the
#notification permission is one switch for everything: unactionable pings are
#what make somebody turn the lot off, taking the match push down with them.
#
#NOR IS A DECLINE, AN EXPIRY, A REMOVAL OR A REPORT. None of them give the
#recipient anything to do, and the matches page already says what happened -
#an expired match is shown saying so for two days, and a declined one simply
#is not there. A notification about a non-event is worse than silence.

from firebase_admin import messaging, firestore

def send_smart_notification(target_uid: str, notification_type: str, db_firestore):
    """
    Sends a notification ONLY if the user has it switched on.

    Args:
        target_uid: The Firebase UID of the recipient.
        notification_type: 'match' (somebody matched with you, said yes, and
            is waiting on your answer) or 'match_revealed' (they said yes
            back, so the handles are out). Anything else is ignored rather
            than sent under a generic title.
        db_firestore: The firestore client instance.
    """

    user_ref = db_firestore.collection('users').document(target_uid)
    user_doc = user_ref.get()

    if not user_doc.exists: 
        #User not found so we skip
        return
    
    user_data = user_doc.to_dict()
    fcm_token = user_data.get('fcm_token')

    if not fcm_token:
        #User has no fcm token so we skip
        return
    

    #ONE TOGGLE, AND IT COVERS BOTH. It used to be a like toggle that happened
    #to gate matches too, which meant turning off the useless pings also
    #turned off "somebody is waiting on your answer" - the one push that
    #carries the whole point of the app. The pings are gone, so the switch now
    #means what its name says.
    #
    #IT CAN BE TURNED OFF, deliberately. The OS switch can do it anyway, so
    #refusing to here would not keep anybody reachable; it would only make the
    #app the thing you have to silence wholesale rather than in part.
    #
    #DEFAULTS TO ON for a document that has no such field yet - a user who has
    #never touched the setting is a user who has not asked for silence.
    match_notifications = user_data.get('match_notifications', True)

    if notification_type in ('match', 'match_revealed'):
        should_send = match_notifications
    #ANYTHING ELSE IS DROPPED rather than sent under a generic title. A kind
    #this function does not know about is a bug at the call site, and
    #"New activity" is how that bug reaches a user's phone instead of a log.
    else:
        should_send = False

    if not should_send:
        #User has disabled this category of notification
        return

    notification_content = {
        #Their turn: somebody matched with them and has already said yes.
        #Deliberately vague about who - the match page is where that is shown.
        'match': {
            'title': "It's a Match!",
            'body': 'Someone matched with you and is waiting on your answer.'
        },
        'match_revealed': {
            'title': "You're connected",
            'body': 'You both said yes. Open the app to see their Instagram.'
        },
    }


    if should_send:
        content = notification_content.get(notification_type, {
            'title': 'New activity',
            'body': 'You have a new notification'
        })

        try:
            message = messaging.Message(  
                token=fcm_token,
                data = {
                    "type": notification_type,
                    "click_action": "FLUTTER_NOTIFICATION_CLICK"
                },
                notification=messaging.Notification(  
                    title=content['title'],
                    body=content['body']
                )
            )
            response = messaging.send(message)
        except Exception:
            return

#What the bell is written with. Lives beside the push sender because the two
#are one decision - see the docstring.
#
#NOTE ON THE NAME: this module is the notification SERVICE (sending and
#recording); routers/notifications.py is the two endpoints that read the rows
#back. Absolute imports keep them apart.
from sqlalchemy.orm import Session

from app_logging import logger
from database import models
from firebase_app import firestore_db


def push(user: models.User, kind: str) -> None:
    """Send a push and nothing else - no row, no record.

    FOR THE THINGS THE MATCHES PAGE ALREADY KNOWS. A match that is waiting on
    somebody is visible the moment they open that page, so a stored
    notification would only be a staler second copy of it. The push still
    earns its place: it is what brings them back to the app at all.

    NOTHING HERE MAY FAIL THE CALLER. The thing being announced is already
    committed, and a missing FCM token or a Firebase outage must not turn a
    confirmed match into an error for the person who just confirmed it.

    Called instead of reaching for send_smart_notification directly, so there
    is one place this is done - and so a test that replaces the sender in this
    module actually replaces it for every caller. An endpoint that imported
    the name itself would hold its own reference and quietly keep the real one.
    """
    try:
        send_smart_notification(user.firebase_uid, kind, firestore_db)
    except Exception as exc:
        logger.warning("push failed (%s): %s: %s", kind, type(exc).__name__, exc)


def notify(db: Session, user: models.User, kind: str, *,
            match_id: int | None = None, other_user_id: int | None = None,
            once: bool = False, push: bool = True) -> None:
    """Record a notification AND try to push it, in that order.

    THE ROW IS THE DELIVERY, the push is a nudge. Firebase can be down, the
    device can have no token, the user can have swiped the banner away before
    reading it - none of which may lose the fact that something happened. The
    row is written on the caller's session and committed with whatever else
    the caller is doing, so a notification cannot exist without the change
    that caused it, or the other way round.

    `once` makes it idempotent for a given (user, kind, match). The endpoints
    around it are safe to call twice - that is the whole point of a retry -
    but "safe" has to include not telling somebody the same thing twice. A
    client whose connection dropped AFTER the server committed will send the
    same request again, and must not produce a second notification.

    `push` is False when the user is already looking at the thing it is about:
    a device notification about the page in front of you is noise.
    """
    if once and match_id is not None:
        already = db.query(models.Notifications).filter(
            models.Notifications.user_id == user.id,
            models.Notifications.kind == kind,
            models.Notifications.match_id == match_id,
        ).first()
        if already:
            return

    db.add(models.Notifications(
        user_id=user.id,
        kind=kind,
        match_id=match_id,
        other_user_id=other_user_id,
    ))
    if not push:
        return
    try:
        send_smart_notification(user.firebase_uid, kind, firestore_db)
    except Exception as exc:
        #already recorded, so the app will show it on next launch regardless
        logger.warning("push failed (%s): %s: %s", kind, type(exc).__name__, exc)
