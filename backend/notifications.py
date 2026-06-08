#File that handles sending notifications about messages or like

from firebase_admin import messaging, firestore

def send_smart_notification(target_uid: str, notification_type: str, db_firestore):
    """
    Sends a notification ONLY if the user has enabled that specific category.
    
    Args:
        target_uid: The Firebase UID of the recipient.
        notification_type: One of 'like', 'match', or 'message'.
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
    message_notifications = user_data.get('message_notifications', True)

    #Map each category to the toggle that governs it: likes and matches are
    #gated by the like toggle, messages by the message toggle. (Previously a
    #message could be sent based on the like setting, and vice versa.)
    if notification_type in ('like', 'match'):
        should_send = like_notifications
    elif notification_type == 'message':
        should_send = message_notifications
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
        'match': {
            'title': "It's a Match!",
            'body': 'You have a new match. Say hi!'
        },
        'message': {
            'title': 'New Message',
            'body': 'You received a new message. Tap to reply.'
    }}


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