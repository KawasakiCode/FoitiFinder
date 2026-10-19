"""Photos, their order, and the stories attached to them."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth import current_uid, verified_claims, verified_email_uid
from database import models, schemas
from database.database import get_db

router = APIRouter()

from api_models import PhotoStory, PhotoSync, UserPhotos

#get users photos
@router.get("/photos")
def get_user_photos(uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    
    photos = db.query(models.Photos).filter(  
        models.Photos.user_id == me.id
    ).order_by(models.Photos.display_order.asc()).all()
    
    return photos

#store a photo inside the db
@router.post("/photos")
def upload_photo(user_photos: UserPhotos, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")
    
    new_photo = models.Photos(  
        user_id = me.id,
        photo_url = user_photos.photo_url,
        display_order = user_photos.display_order,
    ) 

    db.add(new_photo)
    db.commit()
    db.refresh(new_photo)

#Reconcile a user's photos to the given ordered list. The edit-profile page
#uploads only NEW files to Firebase Storage (existing photos keep their URL),
#then sends the final ordered URLs here. We wipe and re-insert the rows so
#unchanged photos are never duplicated, removed ones are deleted, and
#The app's own bounds (kMinPhotos / kMaxPhotos in widgets/photo_card.dart),
#enforced here so they hold even when the request does not come from the app.
MIN_PHOTOS = 3

MAX_PHOTOS = 6

#display_order matches the order the user arranged. Only the photo rows are
#touched — the Firebase Storage objects of kept photos are reused via their URL.
@router.put("/photos/sync")
def sync_photos(payload: PhotoSync, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")

    #EVERY ACCOUNT KEEPS AT LEAST THREE PHOTOS. This endpoint replaces the
    #whole set, so a short list means "delete the rest" - and the profile page
    #is built around three (one after the answers, one after the hobbies, the
    #rest at the end), while the swipe card asks "want to see more?".
    #
    #The app already prevents it (signup will not continue under three, and the
    #edit grid refuses the removal), but that is a rule in one client. A patched
    #build, a crash mid-upload, or a direct call would otherwise leave an
    #account with a profile nobody wants to look at.
    if len(payload.photo_urls) < MIN_PHOTOS:
        raise HTTPException(
            status_code=400,
            detail=f"At least {MIN_PHOTOS} photos are required",
        )

    #...and no more than the grid can hold. The app offers exactly MAX_PHOTOS
    #slots, so a longer list can only come from a patched client or a bug, and
    #the extra rows would be stored and then never shown anywhere.
    if len(payload.photo_urls) > MAX_PHOTOS:
        raise HTTPException(
            status_code=400,
            detail=f"At most {MAX_PHOTOS} photos are allowed",
        )

    #This endpoint wipes and re-inserts, so a photo's story would be destroyed
    #every time the user merely REORDERED their photos. Remember the stories by
    #URL first and re-attach them: a photo that survives the sync keeps its
    #story, one that was removed takes its story with it.
    existing_stories = {
        p.photo_url: p.story
        for p in db.query(models.Photos).filter(
            models.Photos.user_id == me.id
        ).all()
    }

    db.query(models.Photos).filter(
        models.Photos.user_id == me.id
    ).delete(synchronize_session=False)

    for order, photo_url in enumerate(payload.photo_urls):
        db.add(models.Photos(
            user_id=me.id,
            photo_url=photo_url,
            display_order=order,
            #position 0 is the profile picture, which has no story - a photo
            #dragged into that slot leaves its story behind rather than
            #keeping one nothing will ever display
            story=None if order == 0 else existing_stories.get(photo_url),
        ))

    me.has_photos = len(payload.photo_urls) > 0
    db.commit()
    return {"message": "photos synced"}

#Set (or clear) the story attached to a single photo.
#
#Separate from /photos/sync on purpose: writing a caption should not require
#re-uploading and re-ordering the whole photo set, and this way the story page
#saves one row without touching anything else.
@router.put("/photos/story")
def set_photo_story(payload: PhotoStory, uid: str = Depends(verified_email_uid), db: Session = Depends(get_db)):
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")

    photo = db.query(models.Photos).filter(
        models.Photos.user_id == me.id,
        models.Photos.photo_url == payload.photo_url,
    ).first()
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")

    #The profile picture gets no story. It is shown beside a name in the feed,
    #the likes list and matches, where there is nowhere to put a caption, so a
    #story on it would be written and never read. The app hides the option;
    #this is what makes it a rule rather than a UI convention.
    if photo.display_order == 0:
        raise HTTPException(
            status_code=400,
            detail="The profile picture cannot have a story",
        )

    story = (payload.story or "").strip()
    #an empty box means "remove the story", not "store a blank one"
    photo.story = story if story else None

    db.commit()
    return {"message": "story saved"}
