"""Reporting somebody, and what it does besides writing a row."""

import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

import report_reasons
from api_models import ReportRequest
from app_logging import logger
from auth import verified_email_uid
from database import models
from database.database import get_db

router = APIRouter()


@router.post("/reports", status_code=status.HTTP_201_CREATED)
def create_report(report: ReportRequest,
                  uid: str = Depends(verified_email_uid),
                  db: Session = Depends(get_db)):
    """File a report, drop the person from the deck, and leave their match.

    THREE THINGS IN ONE TRANSACTION, because a report that half-landed is
    worse than none: the row written but the person still in your deck, or the
    swipe recorded and the reason lost. The app makes one call and either all
    of it happened or none of it did.

    REPORTING HIDES ONLY YOUR OWN COPY of a match, never theirs - see the note
    on Matches.hidden_by_a_at. If a report made the match vanish for the other
    person too, a match disappearing would tell somebody holding your
    Instagram handle that you had reported them, which is the one thing this
    whole flow exists to avoid.

    ANONYMOUS TO THEM, NOT ANONYMOUS. reporter_id is written and kept. The
    reported user is never told who said it; a reviewer has to be able to see
    the same person reporting fifteen profiles in an afternoon.
    """
    me = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if not me:
        raise HTTPException(status_code=404, detail="Current User not found")

    #VALIDATED AS A PAIR. A subcategory that exists under a DIFFERENT category
    #is a client bug, and accepting it would file a report nobody can read -
    #'minor_sexual_content' sitting under 'fake_profile' means nothing.
    if not report_reasons.is_valid(report.category, report.subcategory):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Unknown report reason",
        )

    if report.reported_user_id == me.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot report yourself",
        )

    them = db.query(models.User).filter(
        models.User.id == report.reported_user_id).first()
    if not them:
        raise HTTPException(status_code=404, detail="Reported user not found")

    #THE MATCH, IF THERE IS ONE, found before anything is written because it
    #also decides whether this category is allowed at all.
    match = db.query(models.Matches).filter(
        or_(and_(models.Matches.user_a_id == me.id,
                 models.Matches.user_b_id == them.id),
            and_(models.Matches.user_a_id == them.id,
                 models.Matches.user_b_id == me.id)),
    ).first()

    #ONE CATEGORY NEEDS A MATCH TO HAVE HAPPENED. Harassment here means what
    #somebody did after they had your handle, which cannot be true of a
    #stranger in the deck - so a report of it without a match is either a
    #confused client or somebody reaching for the worst-sounding option.
    #
    #THE APP ALREADY HIDES THE GROUP in that case; this is the backstop, and
    #it is worth having because the two reads must agree.
    if report.category == report_reasons.AFTER_MATCH_ONLY and match is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="That reason needs a match",
        )

    db.add(models.Reports(
        reporter_id=me.id,
        reported_user_id=them.id,
        category=report.category,
        subcategory=report.subcategory,
        #blank is stored as nothing, so "has anybody written anything here" is
        #a null check rather than a check for null-or-empty-or-whitespace
        details=(report.details or "").strip() or None,
    ))

    #OUT OF THE DECK, FOR GOOD. 'reported' is final in record_swipe: a later
    #like cannot overwrite it, which is what stops a retry queue delivering
    #an old swipe and rebuilding a match with somebody just reported.
    swipe = db.query(models.UserSwipes).filter(
        models.UserSwipes.user_id == me.id,
        models.UserSwipes.target_id == them.id,
    ).first()
    if swipe:
        swipe.action = "reported"
        swipe.timestamp = datetime.datetime.now(datetime.timezone.utc)
    else:
        #reported from a match without a swipe of their own is not reachable
        #today, but a report that failed for lack of a row would be absurd
        db.add(models.UserSwipes(user_id=me.id, target_id=them.id,
                                 action="reported"))

    #AND OFF MY OWN MATCH LIST. Hiding only my side, exactly as the remove
    #button does - the two are the same mechanism and must stay that way, or
    #the difference between them becomes something the other person can see.
    if match is not None:
        now = datetime.datetime.now(datetime.timezone.utc)
        if match.user_a_id == me.id:
            match.hidden_by_a_at = match.hidden_by_a_at or now
        else:
            match.hidden_by_b_at = match.hidden_by_b_at or now

    db.commit()

    #LOUD FOR THE SEVERE ONES, and this is the whole of "routing" for now.
    #A log line is not a pager, but it is in the one place somebody is
    #already looking when something is wrong, and it names no user text - the
    #ids are enough to find the row.
    if report_reasons.is_urgent(report.subcategory):
        logger.warning("URGENT report: %s/%s against user %s",
                       report.category, report.subcategory, them.id)

    #NOTHING ABOUT THE REPORT COMES BACK, not even its id. The app has no
    #screen that would show one, and a report id handed to a client is a
    #handle on somebody else's accusation.
    return {"reported": True}
