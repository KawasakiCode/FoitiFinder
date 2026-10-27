"""The shapes the API sends back, as opposed to the shapes the database has.

TWO PYDANTIC HOMES, deliberately:

  database/schemas.py  mirrors the ORM - what a user IS, what may be patched
  api_models.py        what a particular endpoint answers with

A feed card is not a user: it is a name, an age, a job and some photo URLs,
chosen because that is all the deck needs and everything omitted is something
a stranger does not get to see. Keeping these apart is what stops a column
added to the model from appearing in every response by accident.
"""

import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field

#class that handles the like data we need to sent
#we dont return likes but data from the users that liked the currentuser
class LikerProfile(BaseModel):
    id: int
    name: str
    age: Optional[int] = None
    #OPTIONAL, AND THAT IS A BUG FIX. The photo is an OUTER join, so a liker
    #with no photo 0 arrives as None - and a required str here made FastAPI
    #raise a ResponseValidationError, which is a 500 for the WHOLE likes page
    #because of one half-finished account. The app draws its own placeholder.
    image_url: Optional[str] = None

    class Config:
        #this ensures that pydantic can read sqlalchemy objects
        from_attributes = True

#class that handles sending back users photos
#NOTE: no firebase_uid — the owner is taken from the verified ID token
class UserPhotos(BaseModel):
    photo_url: str
    display_order: int

    class Config:
        from_attributes = True

#class that is used to return to the frontend card data with photos
class UserCards(BaseModel):
    id: int
    name: str
    age: Optional[int] = None
    #shown under the name on the swipe card, so it travels with the card
    job: Optional[str] = None
    bio: Optional[str] = None
    photos: List[str] = []
    #THE ONE THING THE DECK IS ALLOWED TO SAY ABOUT SOMEBODY'S INTEREST.
    #
    #A plain like is invisible: you only learn about it if you like them back
    #on your own. A super like is the sender spending a scarce thing to waive
    #that for themselves, so it is disclosure they chose, not a hole in the
    #rule - and telling you BEFORE you decide is the whole of what it does.
    super_liked_you: bool = False

    class Config:
        from_attributes = True

#class that sends the match data
class MatchResponse(BaseModel):
    """One row of the matches page.

    CARRIES THE STATE, NOT THE HANDLE. The list has to show whether a match is
    waiting on you, waiting on them, or finished - but the Instagram handle
    still crosses between two users in confirm_match and nowhere else, so the
    page asks for it there (the call is idempotent) rather than having a second
    endpoint that can hand it over. A list endpoint is exactly the kind of
    place a handle leaks from by accident.
    """
    match_id: int
    other_user_id: int
    other_user_name: str
    other_user_age: Optional[int] = None
    image_url: Optional[str] = None
    #whether each side has said yes. Both true AND both handles present is
    #`revealed`, which is the same condition confirm_match reveals on.
    i_confirmed: bool = False
    they_confirmed: bool = False
    revealed: bool = False
    #RAN OUT UNANSWERED. Three days after it became somebody's turn, an
    #unconfirmed match stops being served - see match_expiry. For a short
    #window before that it is still sent with this set, so the page can say
    #it lapsed instead of letting it disappear between two refreshes.
    expired: bool = False
    #when it will run out, so the page can name the day rather than quote a
    #rule. Null once both sides have confirmed, because nothing expires then.
    expires_at: Optional[datetime.datetime] = None

    class Config:
        from_attributes = True

#Filing a report.
#
#THE CODES ARE NOT Literal HERE, unlike SwipeRequest's action. A Literal would
#have to list every category and subcategory pair as a flat set, which cannot
#express that a subcategory belongs to one category - and 'minor_sexual_content'
#accepted under 'fake_profile' is a report nobody can read. report_reasons
#validates the PAIR, in the one place the taxonomy lives.
class ReportRequest(BaseModel):
    reported_user_id: int
    category: str
    subcategory: str
    #WHAT THE REPORTER TYPED, and usually the only part that makes a report
    #actionable. Capped, not required: insisting on it turns "I would rather
    #not write this out" into "I will not report it", and a cap stops the
    #column being used as storage.
    details: Optional[str] = Field(default=None, max_length=2000)


#One row of the bell.
#
#NO INSTAGRAM HANDLE, and no text. The handle is only ever handed over by
#/matches/{id}/confirm, so a notification list that carried it would be a
#second, unguarded route to the same thing. The wording lives in the app,
#where it is already translated - the server sends what happened, not how to
#say it.
class NotificationItem(BaseModel):
    id: int
    kind: str
    #null when the match it referred to is gone, which is a notification with
    #nothing to open
    match_id: Optional[int] = None
    other_user_id: Optional[int] = None
    other_name: Optional[str] = None
    other_photo_url: Optional[str] = None
    created_at: datetime.datetime
    read: bool
    #WHETHER THERE IS STILL SOMETHING TO DO. Computed from the match it points
    #at, not from the kind: "someone is waiting on your answer" stops being
    #true the moment you answer, and the notification saying it does not
    #change. The app uses this to decide whether the row opens anything, so a
    #spent notification cannot reopen a decision that has already been made.
    actionable: bool
    #Whether the OTHER side has said yes. The same 'match' kind goes to both
    #of them - the person being matched with, and the one who completed it -
    #and only one of those can be told "they already said yes". Read live from
    #the match rather than frozen at creation, so it is right whenever the
    #list is opened.
    other_confirmed: bool

    class Config:
        from_attributes = True

#class that sends swipe record data
#NOTE: no firebase_uid — the swiper is taken from the verified ID token; only
#the target (someone else) may come from the client
class SwipeRequest(BaseModel):
    target_id: int
    #LITERAL, NOT str. An unconstrained string meant a typo'd action ('lik')
    #was stored happily and then behaved like nothing: not a like, so no match
    #and no appearance on the likes page, but still a swipe, so the person was
    #gone from the deck forever. FastAPI turns anything else into a 422 before
    #the endpoint runs - which is also what makes a 422 here MEAN something,
    #and therefore worth alerting on.
    #'reported' is a pass that can never be undone. It is kept distinct from
    #'pass' on purpose: the two are identical to the deck, but a feature that
    #ever offers a second look at profiles you skipped must not hand back
    #somebody you reported, and by then the two would be indistinguishable.
    action: Literal["like", "pass", "super_like", "reported", "not_interested"]

#body for replacing a user's whole photo set in order
#NOTE: no firebase_uid — the owner is taken from the verified ID token
class PhotoSync(BaseModel):
    photo_urls: List[str]

#body for setting one photo's story
#NOTE: no firebase_uid - the owner is taken from the verified ID token, and
#the photo is looked up scoped to that owner so one user cannot caption
#another user's photo by guessing a URL.
class PhotoStory(BaseModel):
    photo_url: str
    #150 matches kStoryMaxLength in the app. The field there stops typing; this
    #stops a patched client, which is the only reason a length rule in one
    #place is not a rule at all.
    story: Optional[str] = Field(default=None, max_length=150)
