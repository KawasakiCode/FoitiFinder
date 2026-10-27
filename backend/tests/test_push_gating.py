"""Which pushes go out, and which the switch can stop.

NOT COVERED BY THE `pushes` FIXTURE. That one replaces send_smart_notification
entirely and records what the routers ASKED for, which is the right seam for
"who gets told" rules. The decision of whether an asked-for push is actually
sent lives inside the function it replaces, so it needs testing from the other
side - with a fake Firestore document and a fake messaging.send.

WHAT CHANGED, AND WHY IT IS WORTH PINNING. The switch used to be a LIKE
toggle, and it gated the 'match' push too: turning off pings nobody asked for
also turned off "somebody matched with you and is waiting on your answer" -
the one push carrying the whole payoff of the app. The like push is gone, and
the switch now means what its name says and covers both match pushes.
"""

import notifications


class FakeDoc:
    def __init__(self, data):
        self._data = data
        self.exists = data is not None

    def to_dict(self):
        return self._data


class FakeFirestore:
    """Just enough of the client for collection(...).document(...).get()."""

    def __init__(self, data):
        self._data = data

    def collection(self, _name):
        return self

    def document(self, _uid):
        return self

    def get(self):
        return FakeDoc(self._data)


def sent_for(monkeypatch, kind, user_data, match_id=None):
    """The messages send_smart_notification would hand to Firebase."""
    out = []
    monkeypatch.setattr(notifications.messaging, "send",
                        lambda message: out.append(message) or "id")
    notifications.send_smart_notification(
        "uid-them", kind, FakeFirestore(user_data), match_id=match_id)
    return out


ON = {"fcm_token": "tok", "match_notifications": True}
OFF = {"fcm_token": "tok", "match_notifications": False}
UNSET = {"fcm_token": "tok"}


class TestTheSwitchCoversBothMatchPushes:
    def test_match_is_sent_when_on(self, monkeypatch):
        assert len(sent_for(monkeypatch, "match", ON)) == 1

    def test_and_stopped_when_off(self, monkeypatch):
        #THE USER IS ALLOWED TO TURN THIS OFF. The OS switch can do it anyway,
        #so refusing here would not keep anybody reachable - it would only
        #make the app something you silence wholesale instead of in part.
        assert sent_for(monkeypatch, "match", OFF) == []

    def test_match_revealed_is_sent_when_on(self, monkeypatch):
        assert len(sent_for(monkeypatch, "match_revealed", ON)) == 1

    def test_and_match_revealed_is_stopped_too(self, monkeypatch):
        #IT USED TO IGNORE THE TOGGLE, on the grounds that the outcome of a
        #match is not promotional. True, but it made the switch mean two
        #different things depending on which half of the exchange you were in.
        assert sent_for(monkeypatch, "match_revealed", OFF) == []

    def test_a_user_who_never_touched_it_is_told(self, monkeypatch):
        #not having asked for silence is not the same as asking for it
        assert len(sent_for(monkeypatch, "match", UNSET)) == 1


class TestWhatIsNoLongerSentAtAll:
    def test_a_like_is_not_a_push_any_more(self, monkeypatch):
        #THE KIND IS GONE, not merely switched off. Without a likes page the
        #notification pointed at a deck where that person cannot be found.
        assert sent_for(monkeypatch, "like", ON) == []

    def test_nor_is_a_decline(self, monkeypatch):
        assert sent_for(monkeypatch, "match_declined", ON) == []

    def test_nor_anything_this_function_does_not_know(self, monkeypatch):
        #DROPPED, NOT SENT UNDER A GENERIC TITLE. An unrecognised kind is a
        #bug at the call site, and 'New activity' is how such a bug reaches
        #somebody's phone instead of staying in a log.
        assert sent_for(monkeypatch, "message", ON) == []
        assert sent_for(monkeypatch, "something_new", ON) == []


class TestNothingToSendTo:
    def test_a_user_with_no_document(self, monkeypatch):
        assert sent_for(monkeypatch, "match", None) == []

    def test_a_user_with_no_token(self, monkeypatch):
        #signed in on no device, or never granted the permission
        assert sent_for(monkeypatch, "match", {"match_notifications": True}) == []


class TestWhatTheMessageCarries:
    def test_the_kind_travels_in_the_data_payload(self, monkeypatch):
        #the app routes a TAPPED push on this, so it is the one field that has
        #to survive a rename of the user-facing text
        message = sent_for(monkeypatch, "match", ON)[0]
        assert message.data["type"] == "match"

    def test_it_does_not_say_who(self, monkeypatch):
        #A PUSH IS READ ON A LOCKED SCREEN. The match page is where a name
        #belongs; a banner naming somebody shows it to whoever is holding the
        #phone, and for a revealed match that is one step from the handle.
        for kind in ("match", "match_revealed"):
            message = sent_for(monkeypatch, kind, ON)[0]
            assert "uid-them" not in message.notification.body
            assert message.notification.body

class TestTheTapCanFindTheMatch:
    """match_id in the data payload: what makes a tapped banner go somewhere.

    WITHOUT IT the app can only open the matches list and leave the user to
    find the row themselves - which was the state of things, and the reason
    the push felt like a dead end even though it was correct.
    """

    def test_the_id_travels(self, monkeypatch):
        message = sent_for(monkeypatch, "match", ON, match_id=57)[0]
        assert message.data["match_id"] == "57"

    def test_as_a_string(self, monkeypatch):
        #FCM DATA VALUES ARE STRINGS over the wire, and the SDK rejects an int
        #rather than coercing it - so this would fail at send time, on the one
        #path no test exercises if the type is only checked by eye.
        message = sent_for(monkeypatch, "match", ON, match_id=57)[0]
        assert isinstance(message.data["match_id"], str)

    def test_both_kinds_carry_it(self, monkeypatch):
        #the app does not branch on the kind - both open the same match - so
        #a kind that arrived without an id would be a banner leading nowhere
        for kind in ("match", "match_revealed"):
            message = sent_for(monkeypatch, kind, ON, match_id=57)[0]
            assert message.data["match_id"] == "57"

    def test_absent_rather_than_the_string_none(self, monkeypatch):
        #str(None) is "None", which the app would then have to recognise as
        #meaning absent - a second spelling of null, and the kind of thing
        #that is only found by tapping a banner and watching nothing happen
        message = sent_for(monkeypatch, "match", ON)[0]
        assert "match_id" not in message.data
