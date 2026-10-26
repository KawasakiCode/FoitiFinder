"""The oldest build of the app this backend will still talk to.

WHAT THIS IS FOR. A build already on somebody's phone cannot be changed, only
replaced - and until they replace it, it keeps calling this API. That is fine
while every change is additive, which is the discipline the migrations follow:
a new column is invisible to an old client. It stops being fine the moment
something is REMOVED. Dropping a column is only safe once no build still reads
it, and without a number like this one you can never know that, you can only
hope. This is what turns that hope into something you can enforce.

The other two uses are a security fix that has to come off phones, and a
client bug that writes bad data server side - a retry queue that double-sends,
say, where leaving the old build running keeps making the mess worse.

A BUILD NUMBER, NOT A VERSION NAME. pubspec.yaml carries both (`1.0.0+1`): the
name is for people and the number is Android's versionCode, which only ever
goes up. Comparing integers has no edge cases, while comparing version names
as strings quietly decides that 1.10.0 is older than 1.9.0.

A CONSTANT, NOT A DATABASE ROW OR A CONSOLE TOGGLE. Raising it is then a
one-line commit that goes out through the same pipeline as everything else,
with a diff and a message saying why - and "who raised this, and what for" is
exactly the question somebody asks six months later. A value flipped in a
dashboard answers it with silence.

PER PLATFORM, although only Android ships today. The two stores review and
release on their own schedules, so a single shared number is wrong the first
week iOS exists.

RAISING THIS LOCKS PEOPLE OUT. Nothing about it is gradual: every build below
the number stops working the moment the deploy lands, so it is raised when a
build genuinely must stop talking to this API, and not as a nudge to update.
A softer "an update is available" prompt is a second, lower number, and it
does not exist yet.
"""

MINIMUM_BUILD = {
    #1 is the first build there has ever been, so this currently blocks
    #nobody - which is the point. The CHECK has to exist in the shipped
    #binary; a build that never asks can never be told to stop, so every
    #release made before this landed would have been beyond reach forever.
    "android": 1,
}
