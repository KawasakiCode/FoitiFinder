#File that handles sending notifications about likes and matches

from firebase_admin import messaging, firestore

def send_smart_notification(target_uid: str, notification_type: str, db_firestore):
    """
    Sends a notification ONLY if the user has enabled that specific category.
    
    Args:
        target_uid: The Firebase UID of the recipient.
        notification_type: 'like', 'match' (someone is waiting on your
            answer), 'match_revealed' (both of you said yes), 'match_declined'
            (the person you were waiting on said no), or 'message'.
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
    

    like_notifications = user_data.get('like_notifications', True)

    #Likes and matches are gated by the like toggle.
    if notification_type in ('like', 'match'):
        should_send = like_notifications
    #THE OUTCOME OF A MATCH IS NOT PROMOTIONAL, so it ignores the toggle. The
    #user asked for this exchange by confirming the match; the answer to it -
    #a handle, or the fact that it is off - is the thing they are waiting for,
    #and there is no in-app chat to find it in later. The toggle exists to
    #stop "someone liked you" pings, which nobody asked for.
    elif notification_type in ('match_revealed', 'match_declined'):
        should_send = True
    else:
        should_send = False

    if not should_send:
        #User has disabled this category of notification
        return

    notification_content = {
        'like': {
            'title': 'New Like!',
            'body': 'Someone just liked your profile. Open the app to see who!'
        },
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
        'match_declined': {
            'title': 'Match closed',
            'body': "This one didn't go through. Plenty more out there."
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