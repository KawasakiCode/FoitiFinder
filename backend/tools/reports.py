"""Read the report queue: what has been said about whom, and what is waiting.

THE TABLE HAD NO READER. reports has existed since the report sheet shipped,
with a reviewed_at column and a partial index built for a queue - and nothing
anywhere selected from it. Reports arrived, the reporter was told we would
look, and there was no way to look. This is the looking.

READ ONLY. It never writes, so it is safe to point at production, which is the
only place real reports are. Marking one reviewed is the other tool,
tools/review_reports.py, deliberately kept apart: the thing you do fifty times
a week should not be one typo away from the thing that empties the queue.

    cd backend
    .\\venv\\Scripts\\python.exe tools\\reports.py
    .\\venv\\Scripts\\python.exe tools\\reports.py --csv queue.csv

ORDERED URGENT FIRST, THEN OLDEST FIRST. A queue read newest-first is a stack,
and the report at the bottom of a stack is the one that has been waiting
longest - which for 'may be under 18' or 'threats or stalking' is the only
number that matters. report_reasons.URGENT decides which those are, so this
tool and the endpoint cannot disagree about severity.

WHAT IT SHOWS THAT A SELECT * WOULD NOT:

    the names behind both ids   a report is about a person, and reviewing one
                                means looking at their profile
    how long it has waited      in days, because "2026-11-01" does not read as
                                late and "5 days" does
    the prior count             how many OTHER reports name the same account.
                                The model's comment makes the point: one
                                complaint and the fifth complaint about the
                                same person are not the same report, and that
                                is invisible row by row.

BOTH USER COLUMNS ARE NULLABLE - they are ON DELETE SET NULL, so a deleted
account leaves its reports readable with nobody attached. Those rows print as
'(deleted)' rather than being skipped: a report whose subject left right after
it was filed is not less interesting.

PERSONAL DATA COMES OUT OF THIS. Names, free text somebody typed about
somebody else, and who reported whom. That is what a moderation tool is, but
the CSV is a file on a laptop with all of it in one place - do not leave it
lying around, and do not commit it. tools/*.csv is gitignored for that reason.
"""

from __future__ import annotations

import argparse
import csv
import datetime
import os
import sys
from urllib.parse import urlsplit

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import func  # noqa: E402
from sqlalchemy.orm import aliased  # noqa: E402

import report_reasons  # noqa: E402
from database.database import SessionLocal, SQLALCHEMY_DATABASE_URL  # noqa: E402
from database import models  # noqa: E402

#every column the CSV carries, in the order a reviewer reads them
CSV_COLUMNS = (
    "id",
    "created_at",
    "waiting_days",
    "urgent",
    "category",
    "subcategory",
    "reported_user_id",
    "reported_user_name",
    "reported_user_university",
    "other_reports_about_them",
    "reporter_id",
    "reporter_name",
    "reviewed_at",
    "details",
)


def describe_database(url: str | None) -> str:
    """Which database this is pointed at, WITHOUT the password.

    The connection string carries credentials and this tool prints a header on
    every run - including runs whose output somebody pastes into a chat.
    """
    if not url:
        return "(no DATABASE_URL)"
    parts = urlsplit(url)
    host = parts.hostname or "?"
    name = (parts.path or "/?").lstrip("/")
    return f"{name} at {host}"


def rows_for(session, args) -> list[dict]:
    """The queue, as plain dicts so the table and the CSV share one shape."""
    reporter = aliased(models.User)
    reported = aliased(models.User)

    query = (
        session.query(models.Reports, reporter, reported)
        #OUTER JOINS, BOTH OF THEM. An inner join would silently drop every
        #report whose subject or reporter has deleted their account, which is
        #the exact set of rows this table exists to keep.
        .outerjoin(reporter, models.Reports.reporter_id == reporter.id)
        .outerjoin(reported, models.Reports.reported_user_id == reported.id)
    )

    if args.state == "pending":
        query = query.filter(models.Reports.reviewed_at.is_(None))
    elif args.state == "reviewed":
        query = query.filter(models.Reports.reviewed_at.isnot(None))

    if args.about is not None:
        query = query.filter(models.Reports.reported_user_id == args.about)
    if args.by is not None:
        query = query.filter(models.Reports.reporter_id == args.by)
    if args.since is not None:
        cutoff = (datetime.datetime.now(datetime.timezone.utc)
                  - datetime.timedelta(days=args.since))
        query = query.filter(models.Reports.created_at >= cutoff)

    found = query.all()

    #URGENCY IS A PYTHON SET, not a column, so the sort happens here rather
    #than in SQL. The queue is small enough that this is free, and keeping
    #report_reasons.URGENT as the single definition is worth more than an
    #ORDER BY - the alternative is a list of codes duplicated in a CASE.
    found.sort(key=lambda row: (
        not report_reasons.is_urgent(row[0].subcategory),
        row[0].created_at,
    ))
    if args.urgent:
        found = [row for row in found
                 if report_reasons.is_urgent(row[0].subcategory)]
    if args.limit:
        found = found[:args.limit]

    #ONE QUERY FOR EVERY PRIOR COUNT, not one per report. The count is wanted
    #for every row, which makes it a group-by, and writing it as one is no
    #harder than the N+1.
    #
    #COUNTED OVER THE WHOLE TABLE, not over the filtered rows: "how much else
    #has been said about this account" has to include the reports that were
    #already reviewed, which is most of the point of asking.
    counts: dict[int, int] = {}
    subject_ids = {row[0].reported_user_id for row in found
                   if row[0].reported_user_id is not None}
    if subject_ids:
        counts = {
            user_id: total
            for user_id, total in session.query(
                models.Reports.reported_user_id, func.count()
            ).filter(
                models.Reports.reported_user_id.in_(subject_ids)
            ).group_by(models.Reports.reported_user_id).all()
        }

    now = datetime.datetime.now(datetime.timezone.utc)
    out = []
    for report, reporter_row, reported_row in found:
        total_about_them = counts.get(report.reported_user_id, 0)
        out.append({
            "id": report.id,
            "created_at": report.created_at.isoformat(),
            "waiting_days": (now - report.created_at).days,
            "urgent": report_reasons.is_urgent(report.subcategory),
            "category": report.category,
            "subcategory": report.subcategory,
            "reported_user_id": report.reported_user_id,
            "reported_user_name": reported_row.name if reported_row else None,
            "reported_user_university": (reported_row.university
                                         if reported_row else None),
            #MINUS THIS ONE, so the number reads as "and also" rather than
            #including the report you are looking at
            "other_reports_about_them": max(0, total_about_them - 1),
            "reporter_id": report.reporter_id,
            "reporter_name": reporter_row.name if reporter_row else None,
            "reviewed_at": (report.reviewed_at.isoformat()
                            if report.reviewed_at else None),
            "details": report.details,
        })
    return out


def print_blocks(rows: list[dict]) -> None:
    """One block per report.

    NOT A TABLE. `details` is free text somebody typed to explain what
    happened, it is usually the only thing that makes a report actionable, and
    it does not fit in a column. A layout that truncates the one field worth
    reading is a layout that sends you to the database anyway.
    """
    for row in rows:
        flag = "  ** URGENT **" if row["urgent"] else ""
        who = row["reported_user_name"] or "(deleted)"
        university = row["reported_user_university"]
        reporter = row["reporter_name"] or "(deleted)"
        print()
        print(f"#{row['id']}  {row['category']} / {row['subcategory']}{flag}")
        print(f"  about     {who}"
              f" (id {row['reported_user_id']}"
              f"{', ' + university if university else ''})")
        if row["other_reports_about_them"]:
            print(f"            {row['other_reports_about_them']} other "
                  f"report(s) about this account")
        print(f"  from      {reporter} (id {row['reporter_id']})")
        waited = row["waiting_days"]
        print(f"  filed     {row['created_at'][:16].replace('T', ' ')}"
              f"  ({waited} day{'' if waited == 1 else 's'} ago)")
        if row["reviewed_at"]:
            print(f"  reviewed  {row['reviewed_at'][:16].replace('T', ' ')}")
        if row["details"]:
            print("  said      " + row["details"].replace("\n", "\n            "))
        else:
            print("  said      (nothing written)")


def write_csv(rows: list[dict], path: str) -> None:
    #utf-8-SIG, not plain utf-8. The details field is written by Greek
    #students and will be Greek; Excel on Windows reads a BOM-less UTF-8 CSV
    #as Windows-1252 and renders every accented character as mojibake, which
    #makes the one field worth reading unreadable.
    with open(path, "w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(CSV_COLUMNS))
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def force_utf8_output() -> None:
    """Print Greek without crashing.

    THE FIRST REAL REPORT WOULD HAVE KILLED THIS TOOL. Python on Windows gives
    stdout the console codepage, which is cp1252 here, and `details` is free
    text written by Greek students - so the moment a report said anything in
    Greek, printing it raised UnicodeEncodeError and the whole queue died at
    whichever row got there first. The one field the tool exists to show is
    the field that broke it.

    errors='replace' on top, so a console that genuinely cannot render a
    character prints a box instead of taking the rest of the queue with it.
    """
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError):
            #not a reconfigurable text stream (redirected oddly, or a test
            #capturing it) - printing is best effort from here
            pass


def main() -> None:
    force_utf8_output()
    parser = argparse.ArgumentParser(
        description="Show the report queue. Read only.",
        epilog="Marking a report reviewed is tools/review_reports.py.",
    )
    state = parser.add_mutually_exclusive_group()
    state.add_argument("--all", dest="state", action="store_const", const="all",
                       help="include reports that have already been reviewed")
    state.add_argument("--reviewed", dest="state", action="store_const",
                       const="reviewed", help="only reviewed reports")
    #DEFAULT IS DECIDED AFTER PARSING, not here - see below.
    parser.set_defaults(state=None)

    parser.add_argument("--urgent", action="store_true",
                        help="only the severe ones (see report_reasons.URGENT)")
    parser.add_argument("--about", type=int, metavar="USER_ID",
                        help="every report about one account, reviewed ones "
                             "included unless you say otherwise")
    parser.add_argument("--by", type=int, metavar="USER_ID",
                        help="every report FROM one account, for spotting "
                             "somebody reporting everybody")
    parser.add_argument("--since", type=int, metavar="DAYS",
                        help="only reports filed in the last DAYS days")
    parser.add_argument("--limit", type=int, help="show at most this many")
    parser.add_argument("--csv", metavar="PATH",
                        help="also write every shown report to a CSV file")
    parser.add_argument("--quiet", action="store_true",
                        help="write the CSV without printing the reports")
    args = parser.parse_args()

    #--about ASKS A HISTORY QUESTION, so it gets the history. The default is
    #the pending queue, which is right for "what is waiting for me" and wrong
    #for "what has been said about this account" - the reports already dealt
    #with are most of the answer to the second one, and filtering them out
    #silently made --about quietly lie about being "every report". An explicit
    #--all or --reviewed still wins, which is why this is decided here rather
    #than as an argparse default.
    if args.state is None:
        args.state = "all" if args.about is not None else "pending"

    print(f"database: {describe_database(SQLALCHEMY_DATABASE_URL)}")

    session = SessionLocal()
    try:
        rows = rows_for(session, args)
    finally:
        session.close()

    if not rows:
        print(f"\nnothing to show ({args.state})")
        return

    if not args.quiet:
        print_blocks(rows)

    urgent = sum(1 for row in rows if row["urgent"])
    print(f"\n{len(rows)} report(s) shown, {urgent} urgent"
          f"{' (state: ' + args.state + ')' if args.state != 'pending' else ' pending'}")

    if args.csv:
        write_csv(rows, args.csv)
        print(f"wrote {args.csv} - it contains names and free text, so treat "
              f"it as personal data")

    if args.state == "pending" and rows:
        ids = " ".join(str(row["id"]) for row in rows[:5])
        print(f"\nto mark some reviewed:\n"
              f"  python tools\\review_reports.py --id {ids}")


if __name__ == "__main__":
    main()
