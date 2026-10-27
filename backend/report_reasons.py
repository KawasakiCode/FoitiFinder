"""What a report can be about: the codes, and nothing else.

CODES HERE, WORDS IN THE APP. This file is the contract - it decides what the
endpoint will accept and what a reviewer will read six months from now - while
every sentence a user sees lives in the app's .arb files. The alternative was
sending titles and option labels down from here, which is how the push
notifications ended up English-only for a bilingual app: text built on the
server cannot be translated by the client that displays it.

A SUBCATEGORY BELONGS TO A CATEGORY, so this is a mapping rather than two
lists. 'minor_sexual_content' arriving under 'fake_profile' is a bug in the
client, and a flat list of valid codes would have accepted it and produced a
report nobody can act on.

WHAT WAS LEFT OUT, and why, because the absences are the design:

  photo quality - 'blurry', 'face not visible', 'photos too similar'. These
  are standards, not reports. A queue that fills with "her photos are bad"
  buries the ones that matter, and the fix is guidance at upload time.

  contact details in the profile - the reporter GAINS the handle and loses
  nothing, so nobody would ever send it. A profile that is really an Instagram
  advert gets reported as spam instead, which is a category people do use.

  "pushed to move the conversation off-app" - there is no in-app conversation.
  Moving to Instagram is the entire product.

  multiple accounts / previously banned - registration needs a university
  email, so this is close enough to impossible to be mostly wrong guesses.

  "history of abuse or criminal activity" - hearsay about somebody's past,
  with nothing to verify and nothing to do.

  "not interested" - not a report at all. It is a pass, which the deck
  already records, and the app offers it in the same sheet so that somebody
  who merely dislikes a profile has somewhere to go other than these options.
"""

#AFTER A MATCH ONLY. Everything else can be judged from a profile in the deck;
#this one is about what somebody did once they had your Instagram, which
#cannot have happened to a stranger you have not matched with. The app hides
#this group before a match and the endpoint refuses it - see create_report.
AFTER_MATCH_ONLY = "harassment"

REASONS: dict[str, tuple[str, ...]] = {
    #Everything visible in the deck: photos, bio, name.
    "profile_content": (
        "nudity_or_sexual",
        "hateful_violent_disturbing",
        "other",
    ),
    #ITS OWN CATEGORY, NEVER FOLDED INTO ANOTHER. There is no server-side age
    #check anywhere in this app - the signup form refuses a birthday under 18
    #and that is the whole of it - so this group is the only backstop that
    #exists. The second code also carries legal reporting duties that differ
    #by country; it is not a thing to answer at leisure.
    "underage": (
        "may_be_under_18",
        "minor_sexual_content",
        "other",
    ),
    "fake_profile": (
        "not_the_person_in_the_photos",
        "impersonation",
        "spam_scam_or_money",
        "other",
    ),
    #Off-platform, after the handles were exchanged. The app cannot see any of
    #it, which is exactly why somebody has to be able to say it happened.
    "harassment": (
        "abusive_messages",
        "threats_or_stalking",
        "sexual_assault",
        "shared_my_information",
        "made_me_feel_unsafe",
        "other",
    ),
}

#THE SEVERE ONES, which exist as a list because the difference has to be
#visible in code and not only in a reviewer's judgement. A report in here is
#not a queue item to look at this week.
URGENT = frozenset({
    "minor_sexual_content",
    "sexual_assault",
    "threats_or_stalking",
})


def is_valid(category: str, subcategory: str) -> bool:
    return subcategory in REASONS.get(category, ())


def is_urgent(subcategory: str) -> bool:
    return subcategory in URGENT
