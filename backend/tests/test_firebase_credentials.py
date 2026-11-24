"""Where the service-account key is looked for.

WHY THIS IS WORTH A TEST AT ALL. It is four lines of path checking, and it
decides whether the backend can authenticate a single human being. With no key
there is no initialised Admin SDK, so verify_id_token raises for every request
and every endpoint answers 401 "Invalid or expired token" - for everybody,
including an account created thirty seconds ago. That last detail is what
makes it expensive: a brand-new account failing looks like a bug in signup, so
the search starts in the signup flow and not in the deploy.

AND IT HAS ALREADY HAPPENED ONCE. The key is gitignored, so on Render it
arrives as a Secret File - which Render places at /etc/secrets/<filename> and,
for non-Docker services, in the service's ROOT DIRECTORY. That is a dashboard
setting. Left blank, the file lands at the repository root while the module
looked only next to itself in backend/. The key was uploaded, correct, and
unreachable, and the only sign was one warning line in the boot log.

WHAT THESE PIN DOWN is therefore the ORDER and the SET of candidate paths. The
module cannot be re-imported per test (initialize_app is global and the real
SDK would be handed a fake certificate), so the tests call the function
directly - which is the reason it is a function and not a module-level
expression.
"""

import os

import firebase_app


class TestWhereItLooks:
    def test_nothing_anywhere_is_none_rather_than_a_crash(self, monkeypatch, tmp_path):
        #IMPORTING THIS MODULE MUST WORK WITH NO CREDENTIALS AT ALL. CI has no
        #secrets, and the whole suite imports the app.
        monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)
        monkeypatch.setattr(firebase_app, "_LOCAL", str(tmp_path / "absent.json"))
        monkeypatch.setattr(os.path, "exists", lambda p: False)

        assert firebase_app.service_account_path() is None

    def test_the_local_file_next_to_the_module(self, monkeypatch, tmp_path):
        #how a laptop and a plain `uvicorn main:app` find it
        monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)
        local = tmp_path / "serviceAccountKey.json"
        local.write_text("{}", encoding="utf-8")
        monkeypatch.setattr(firebase_app, "_LOCAL", str(local))

        assert firebase_app.service_account_path() == str(local)

    def test_etc_secrets_when_the_local_file_is_absent(self, monkeypatch, tmp_path):
        #THE RENDER CASE, AND THE ONE THAT WAS MISSING. /etc/secrets is where a
        #Secret File is readable whatever the service's root directory is set
        #to, so it is the only candidate that cannot be defeated by a
        #dashboard setting.
        monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)
        monkeypatch.setattr(firebase_app, "_LOCAL", str(tmp_path / "absent.json"))
        monkeypatch.setattr(
            os.path, "exists",
            lambda p: p == "/etc/secrets/serviceAccountKey.json",
        )

        assert firebase_app.service_account_path() == \
            "/etc/secrets/serviceAccountKey.json"

    def test_etc_secrets_is_spelled_correctly(self):
        #A GUARD ON THE LITERAL. A typo in this path is a path that never
        #exists, which is indistinguishable from having no key at all - the
        #test above would still pass, because it monkeypatches exists() to
        #agree with whatever the code asks for. Read the real source.
        import inspect

        body = inspect.getsource(firebase_app._candidates)
        assert "/etc/secrets/serviceAccountKey.json" in body


class TestWhichOneWins:
    def test_the_env_var_beats_both(self, monkeypatch, tmp_path):
        #AN EXPLICIT SETTING BEATS A GUESS. GOOGLE_APPLICATION_CREDENTIALS is
        #the standard name for this, and somebody who sets it has said where
        #the key is; finding a different one would be the module overruling
        #them.
        chosen = tmp_path / "chosen.json"
        chosen.write_text("{}", encoding="utf-8")
        ignored = tmp_path / "serviceAccountKey.json"
        ignored.write_text("{}", encoding="utf-8")

        monkeypatch.setenv("GOOGLE_APPLICATION_CREDENTIALS", str(chosen))
        monkeypatch.setattr(firebase_app, "_LOCAL", str(ignored))

        assert firebase_app.service_account_path() == str(chosen)

    def test_an_env_var_pointing_nowhere_falls_through(self, monkeypatch, tmp_path):
        #A STALE SETTING MUST NOT BE A DEAD END. The variable may be left over
        #from another host; a key that is actually present should still be
        #found rather than the process refusing every request because of a
        #path that no longer exists.
        local = tmp_path / "serviceAccountKey.json"
        local.write_text("{}", encoding="utf-8")

        monkeypatch.setenv("GOOGLE_APPLICATION_CREDENTIALS",
                           str(tmp_path / "gone.json"))
        monkeypatch.setattr(firebase_app, "_LOCAL", str(local))

        assert firebase_app.service_account_path() == str(local)

    def test_an_empty_env_var_is_not_a_path(self, monkeypatch, tmp_path):
        #os.path.exists("") is False, so this would fall through anyway - but
        #an empty string reaching Certificate() would be a confusing crash, and
        #an unset-looking variable is a thing deploy UIs produce.
        local = tmp_path / "serviceAccountKey.json"
        local.write_text("{}", encoding="utf-8")

        monkeypatch.setenv("GOOGLE_APPLICATION_CREDENTIALS", "")
        monkeypatch.setattr(firebase_app, "_LOCAL", str(local))

        assert firebase_app.service_account_path() == str(local)


class TestWhatTheProcessReports:
    """The warning is the only symptom this failure ever has."""

    def test_it_names_the_consequence_not_just_the_file(self, monkeypatch):
        #THE WORDING IS THE FEATURE. "serviceAccountKey.json not found" reads
        #as housekeeping and gets scrolled past; what was actually true was
        #that every request in production answered 401, new accounts included.
        #Somebody reading one line of a boot log has to learn that.
        monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)
        message = firebase_app.no_key_warning()

        assert "401" in message
        assert "created seconds ago" in message,             'the clue that it is not a signup bug has to be in the line'

    def test_it_lists_every_place_it_looked(self, monkeypatch, tmp_path):
        #so the reader can compare the list against where they put the file,
        #which is the entire diagnosis
        monkeypatch.setenv("GOOGLE_APPLICATION_CREDENTIALS", str(tmp_path / "x.json"))
        message = firebase_app.no_key_warning()

        for path in firebase_app._candidates():
            assert path in message

    def test_it_says_what_to_do_on_render(self, monkeypatch):
        monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)
        message = firebase_app.no_key_warning()

        assert "Secret File" in message
        assert "/etc/secrets/serviceAccountKey.json" in message
