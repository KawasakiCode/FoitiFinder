"""Mark reports as reviewed - the one write in the moderation path.

reviewed_at ANSWERS ONE QUESTION: has a person looked at this. Not what they
decided. The model says why there is no outcome column - what was done about a
report is a decision about an ACCOUNT and belongs wherever account decisions
are recorded - so this tool sets a timestamp and nothing else, and resisting
the urge to add --verdict here is the whole design.

    cd backend
    .\\venv\\Scripts\\python.exe tools\\review_reports.py --id 12 13 14
    .\\venv\\Scripts\\python.exe tools\\review_reports.py --id 12 --undo

A SEPARATE FILE FROM tools/reports.py, which only reads. Reading the queue is
something you do constantly and from anywhere, including against production;
this empties it. Putting both behind one command would make the dangerous one
a flag away from the safe one, and --all-pending a typo away from the thing
you do fifty times a week.

IT PRINTS WHAT IT IS ABOUT TO CHANGE, AND WHAT IT CHANGED. A tool whose entire
output is silence on success is a tool nobody trusts enough to use on the real
database, which means the queue goes unreviewed.

NOTHING HERE TOUCHES THE ACCOUNT. Suspending or removing somebody is not
automated and should not be: see the guidelines published at site/guidelines.html,
which promise that everything short of the two most severe categories is a
judgement made by a person. This records that the judgement happened.
"""

from __future__ import annotations

import argparse
import datetime
import os
import sys
from urllib.parse import urlsplit

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import report_reasons  # noqa: E402
from database.database import SessionLocal, SQLALCHEMY_DATABASE_URL  # noqa: E402
from database import models  # noqa: E402


def describe_database(url: str | None) -> str:
    """Which database, WITHOUT the password - this prints on every run."""
    if not url:
        return "(no DATABASE_URL)"
    parts = urlsplit(url)
    return f"{(parts.path or '/?').lstrip('/')} at {parts.hostname or '?'}"


def describe(report: models.Reports) -> str:
    flag = " ** URGENT **" if report_reasons.is_urgent(report.subcategory) else ""
    state = ("reviewed " + report.reviewed_at.strftime("%Y-%m-%d %H:%M")
             if report.reviewed_at else "pending")
    return (f"  #{report.id}  {report.category} / {report.subcategory}{flag}"
            f"  about user {report.reported_user_id}  [{state}]")


def main() -> None:
    #SAME REASON AS tools/reports.py: Windows gives stdout the console
    #codepage, and anything Greek reaching a print() raises rather than
    #printing. Nothing here prints free text today, but it prints the output
    #of a database read, and that is where Greek comes from.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            pass

    parser = argparse.ArgumentParser(
        description="Mark reports reviewed, or un-mark them.",
        epilog="Reading the queue is tools/reports.py.",
    )
    which = parser.add_mutually_exclusive_group(required=True)
    which.add_argument("--id", type=int, nargs="+", metavar="N",
                       help="the report ids to mark")
    which.add_argument("--all-pending", action="store_true",
                       help="mark EVERY pending report reviewed; needs --yes")

    parser.add_argument("--undo", action="store_true",
                        help="clear reviewed_at instead of setting it, for a "
                             "report marked by mistake")
    parser.add_argument("--yes", action="store_true",
                        help="skip the confirmation prompt")
    args = parser.parse_args()

    if args.all_pending and args.undo:
        parser.error("--undo needs explicit --id: un-reviewing everything is "
                     "never a thing somebody means")

    print(f"database: {describe_database(SQLALCHEMY_DATABASE_URL)}")

    session = SessionLocal()
    try:
        if args.all_pending:
            targets = (session.query(models.Reports)
                       .filter(models.Reports.reviewed_at.is_(None))
                       .order_by(models.Reports.id).all())
        else:
            targets = (session.query(models.Reports)
                       .filter(models.Reports.id.in_(args.id))
                       .order_by(models.Reports.id).all())
            #AN ID THAT DOES NOT EXIST IS AN ERROR, not something to skip
            #quietly. The ids are typed by hand off the other tool's output,
            #so a wrong one means the report somebody meant to clear is still
            #sitting in the queue - and a silent success would hide that.
            missing = sorted(set(args.id) - {report.id for report in targets})
            if missing:
                print(f"\nno such report: {', '.join(str(i) for i in missing)}")
                print("nothing was changed")
                raise SystemExit(1)

        if not targets:
            print("\nnothing to do: no pending reports" if args.all_pending
                  else "\nnothing to do")
            return

        #ALREADY IN THE STATE BEING ASKED FOR is not an error - it is a retry,
        #or two people reviewing the same queue - but it must not be reported
        #as a change that happened.
        changing = [report for report in targets
                    if (report.reviewed_at is not None) == args.undo]
        changing_ids = {report.id for report in changing}
        unchanged = [report for report in targets
                     if report.id not in changing_ids]

        verb = "un-review" if args.undo else "mark reviewed"
        done = "un-reviewed" if args.undo else "marked reviewed"
        print(f"\nabout to {verb} {len(changing)} report(s):")
        for report in changing:
            print(describe(report))
        for report in unchanged:
            print(f"  #{report.id}  already "
                  f"{'pending' if args.undo else 'reviewed'}, leaving alone")

        if not changing:
            return

        #CONFIRMATION ONLY FOR THE BULK PATH. Naming ids is already the
        #confirmation - you typed them - and a prompt on the common operation
        #is the thing that teaches people to pass --yes out of habit.
        if args.all_pending and not args.yes:
            answer = input(f"\n{verb} all {len(changing)}? [y/N] ").strip().lower()
            if answer not in ("y", "yes"):
                print("nothing was changed")
                return

        now = datetime.datetime.now(datetime.timezone.utc)
        for report in changing:
            report.reviewed_at = None if args.undo else now
        session.commit()

        print(f"\n{len(changing)} report(s) {done}")
    finally:
        session.close()


if __name__ == "__main__":
    main()
