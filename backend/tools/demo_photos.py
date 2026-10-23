"""Put the demo's faces somewhere the app can actually load them from.

WHY THIS EXISTS. seed_local.py pointed every photo at picsum, which returns
landscapes and buildings. That is fine for checking a card lays out and useless
on camera: a dating deck showing a mountain where a face should be reads as
broken. A demo needs faces, and the honest way to get them - without putting a
real person's likeness into a dating app - is to use generated ones.

ONE FOLDER PER PERSON, because a profile is one person seen several times.
Random faces per photo would mean swiping through Maria's photos shows four
different women, which looks worse than the mountain did.

    demo_photos/
      maria/   1.jpg  2.jpg  3.jpg     <- the same generated face, three shots
      eleni/   1.jpg  coffee.jpg       <- a face plus a lifestyle shot

Photos are taken in sorted filename order and photo 0 is the profile picture,
so name the best portrait so it sorts first. A folder with fewer than three
images is topped up by the seeder with scenery, which is what half of the real
profiles on any dating app look like anyway.

The folder name becomes the profile's NAME, so use first names: maria -> Maria.

PUBLIC OBJECTS, OR A YEAR-LONG SIGNED URL. A short-lived signed URL would
expire and leave the finished video pointing at dead images. Everything lands
under demo/ so it is easy to find and delete, and a second run reuses what is
already uploaded instead of filling the bucket with copies.

    cd backend
    .\\venv\\Scripts\\python.exe tools\\demo_photos.py --dir ..\\demo_photos

Writes tools/demo_photos.json, which is what you hand to the seeder:

    .\\venv\\Scripts\\python.exe tools\\seed_local.py --uid <uid> --photos tools\\demo_photos.json
"""

from __future__ import annotations

import argparse
import datetime
import json
import mimetypes
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import firebase_app  # noqa: E402,F401  (imported for its initialisation)
from firebase_admin import storage  # noqa: E402

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}

#Where the manifest lands by default, next to this script rather than in the
#working directory - the seeder is run from backend/ and the path in the
#README has to mean one place.
DEFAULT_MANIFEST = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "demo_photos.json"
)


def default_bucket_name() -> str:
    """`<project>.firebasestorage.app`, read from the service account key.

    Not hardcoded, and not read from lib/firebase_options.dart either: the key
    is the thing that decides which project these uploads can reach at all, so
    it is also the honest source for which bucket they land in.
    """
    key_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "serviceAccountKey.json",
    )
    if not os.path.exists(key_path):
        sys.exit("serviceAccountKey.json not found - cannot reach Storage.")
    with open(key_path, encoding="utf-8") as handle:
        project = json.load(handle).get("project_id")
    if not project:
        sys.exit("serviceAccountKey.json has no project_id.")
    return f"{project}.firebasestorage.app"


def people_in(directory: str) -> dict[str, list[str]]:
    """{person: [local image paths]}, in sorted filename order.

    A flat folder of images is read as one photo each for people named after
    the files, which is the shape you get from downloading a handful of faces
    and not sorting them yet.
    """
    if not os.path.isdir(directory):
        sys.exit(f"{directory} is not a folder.")

    subfolders = sorted(
        entry for entry in os.listdir(directory)
        if os.path.isdir(os.path.join(directory, entry))
    )

    if subfolders:
        people = {}
        for person in subfolders:
            folder = os.path.join(directory, person)
            images = sorted(
                name for name in os.listdir(folder)
                if os.path.splitext(name)[1].lower() in IMAGE_SUFFIXES
            )
            if not images:
                print(f"  {person}: no images, skipped")
                continue
            people[person] = [os.path.join(folder, name) for name in images]
        return people

    loose = sorted(
        name for name in os.listdir(directory)
        if os.path.splitext(name)[1].lower() in IMAGE_SUFFIXES
    )
    if not loose:
        sys.exit(f"No images in {directory} and no subfolders either.")

    #A FLAT FOLDER NAMED <person>_<n>, which is how the files arrive when you
    #generate them: woman1_1.jpeg, woman1_2.jpg, woman1_3.jpg. Grouping on the
    #prefix keeps the three photos of one person together without anybody
    #having to make folders by hand, and the number orders them - so _1 is the
    #profile picture.
    grouped: dict[str, list[tuple[int, str]]] = {}
    ungrouped = []
    for name in loose:
        stem = os.path.splitext(name)[0]
        match = re.match(r"^(.*?)[_-](\d+)$", stem)
        if match:
            grouped.setdefault(match.group(1), []).append(
                (int(match.group(2)), os.path.join(directory, name)))
        else:
            ungrouped.append(name)

    if grouped:
        people = {
            person: [path for _, path in sorted(shots)]
            for person, shots in sorted(grouped.items())
        }
        for person, paths in people.items():
            print(f"  {person}: {len(paths)} photos")
        for name in ungrouped:
            person = os.path.splitext(name)[0]
            people[person] = [os.path.join(directory, name)]
            print(f"  {person}: 1 photo (no _n suffix, so it is its own person)")
        return people

    print("flat folder with no <name>_<number> pattern: one photo per person, "
          "named after each file. Use subfolders or that suffix to give "
          "somebody more than one photo.")
    return {
        os.path.splitext(name)[0]: [os.path.join(directory, name)]
        for name in loose
    }


def readable_url(blob) -> str:
    """A URL the app can load without a token.

    make_public() is the simple answer and it fails on a bucket with uniform
    bucket-level access, which newer Firebase projects have on by default -
    per-object ACLs simply do not exist there. A signed URL works either way,
    so that is the fallback, and it is given a year because the video has to
    outlive it.
    """
    try:
        blob.make_public()
        return blob.public_url
    except Exception as exc:
        print(f"    (not public: {type(exc).__name__} - signing instead)")
        return blob.generate_signed_url(
            expiration=datetime.timedelta(days=365),
            version="v4",
        )


def delete_everything(bucket) -> None:
    """Remove the demo/ prefix again.

    THE SEEDER'S --wipe ONLY REMOVES DATABASE ROWS. These objects live in the
    same Storage bucket the real users' photos are in, so cleaning up after a
    demo is two commands, not one. Scoped to demo/ and nothing else.
    """
    blobs = list(bucket.list_blobs(prefix="demo/"))
    if not blobs:
        print("nothing under demo/ to delete")
        return
    for blob in blobs:
        blob.delete()
        print(f"  deleted {blob.name}")
    print(f"removed {len(blobs)} demo objects")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir",
                        help="folder of images, one subfolder per person")
    parser.add_argument("--delete", action="store_true",
                        help="remove everything previously uploaded under demo/")
    parser.add_argument("--bucket", help="override the Storage bucket")
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST,
                        help="where to write the url list")
    parser.add_argument("--force", action="store_true",
                        help="re-upload images that are already there")
    parser.add_argument("--names",
                        help="comma-separated first names to use instead of "
                             "the folder/prefix names, in the order they are "
                             "listed: --names Maria,Danai,Katerina")
    args = parser.parse_args()

    bucket_name = args.bucket or default_bucket_name()
    bucket = storage.bucket(bucket_name)
    print(f"bucket: {bucket_name}")

    if args.delete:
        delete_everything(bucket)
        return
    if not args.dir:
        sys.exit("--dir is required (or --delete to clean up).")

    people = people_in(args.dir)
    if not people:
        sys.exit("Nothing to upload.")

    #RENAMED HERE, NOT IN THE SEEDER, because the name is what the Storage
    #path is built from too - so the uploaded objects read maria/0.jpg rather
    #than woman1/0.jpeg, and the bucket stays legible months later.
    if args.names:
        wanted = [name.strip() for name in args.names.split(",") if name.strip()]
        if len(wanted) != len(people):
            sys.exit(f"--names has {len(wanted)} names but there are "
                     f"{len(people)} people: {', '.join(people)}")
        people = {
            new: paths
            for new, paths in zip(wanted, people.values())
        }
        print("named: " + ", ".join(people))

    manifest: dict[str, list[str]] = {}
    for person, paths in people.items():
        urls = []
        for index, path in enumerate(paths):
            suffix = os.path.splitext(path)[1].lower()
            blob = bucket.blob(f"demo/{person}/{index}{suffix}")
            if blob.exists() and not args.force:
                print(f"  {person}/{index}{suffix}: already uploaded")
            else:
                content_type = mimetypes.guess_type(path)[0] or "image/jpeg"
                blob.upload_from_filename(path, content_type=content_type)
                print(f"  {person}/{index}{suffix}: uploaded")
            urls.append(readable_url(blob))
        manifest[person] = urls

    with open(args.manifest, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)

    total = sum(len(urls) for urls in manifest.values())
    print(f"\n{len(manifest)} people, {total} photos -> {args.manifest}")
    print("Now seed with:")
    print(f"  .\\venv\\Scripts\\python.exe tools\\seed_local.py --uid <uid> "
          f"--photos {os.path.relpath(args.manifest, os.getcwd())}")


if __name__ == "__main__":
    main()
