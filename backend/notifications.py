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
    #Check if user allows notifications of the specific type we send
    should_send = False

    if notification_type in ['like', 'match', 'message']:
        if like_notifications:
            should_send = True
        elif message_notifications:
            should_send = True
        else: 
            #User has disabled notifications
            return
    
    notification_content = {
        'like': {
            'title': 'New Like!',
            'body': 'Someone just liked your profile. Open the app to see who!'
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