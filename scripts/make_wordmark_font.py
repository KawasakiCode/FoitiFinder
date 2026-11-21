"""Builds assets/fonts/GlutenWordmark.ttf, the font the logo is set in.

    python scripts\\make_wordmark_font.py

WHY A SUBSET AND NOT THE FONT. Gluten ships as a 342 KB variable font and the
app sets exactly one string in it - the wordmark on the login and signup
screens. Instanced at one weight and cut down to the eight letters of
"FoitiFinder" it is under 4 KB, which is the difference between a logo that
costs nothing and one that costs a third of a megabyte in every download.

THE FAMILY IS DELIBERATELY NOT CALLED "Gluten". It cannot set anything but the
wordmark - type any other letter in it and you get a blank - so it is named
for what it is, and anyone who reaches for it elsewhere finds out immediately
rather than shipping a screen full of tofu.

LICENCE. Gluten is under the SIL OFL 1.1, which permits modification and
subsetting. Its copyright line declares no Reserved Font Name, so the derived
font may keep the name; OFL section 2 requires the licence to travel with the
binary, which is why assets/fonts/OFL-Gluten.txt exists. Do not delete it.
"""

import os
import sys
import tempfile
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

FONT_URL = ("https://github.com/google/fonts/raw/main/ofl/gluten/"
            "Gluten%5Bslnt%2Cwght%5D.ttf")
LICENCE_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/gluten/OFL.txt"

WORDMARK = "FoitiFinder"

#Matches the launcher icon - see scripts/make_icon.py for why 500 and not
#something heavier.
WEIGHT = 500
SLANT = 0

FAMILY = "GlutenWordmark"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fonts", "GlutenWordmark.ttf")
LICENCE_OUT = os.path.join(ROOT, "assets", "fonts", "OFL-Gluten.txt")


def download(url, path, minimum):
    if not os.path.exists(path):
        print(f"downloading {os.path.basename(path)} ...")
        urllib.request.urlretrieve(url, path)
    if os.path.getsize(path) < minimum:
        sys.exit(f"{path} is too small to be right; delete it and retry")
    return path


def rename(font):
    """THE INSTANCER LEAVES IT CALLED "Gluten Thin". The variable font's default
    weight is 100, and pinning an axis does not revisit the name table, so the
    output is named after a weight it is not. Flutter does not read these - the
    family comes from pubspec.yaml - but a font that lies about itself is a
    thing someone loses an afternoon to."""
    full = f"{FAMILY} Regular"
    for record in font["name"].names:
        nid = record.nameID
        if nid == 1:
            record.string = FAMILY
        elif nid == 2:
            record.string = "Regular"
        elif nid == 4:
            record.string = full
        elif nid == 6:
            record.string = f"{FAMILY}-Regular"
        elif nid in (16, 17):
            record.string = FAMILY if nid == 16 else "Regular"


def main():
    tmp = tempfile.gettempdir()
    variable = download(FONT_URL, os.path.join(tmp, "Gluten-slnt-wght.ttf"), 10000)
    licence = download(LICENCE_URL, os.path.join(tmp, "Gluten-OFL.txt"), 1000)

    font = TTFont(variable)
    instancer.instantiateVariableFont(font, {"wght": WEIGHT, "slnt": SLANT},
                                      inplace=True, updateFontNames=False)

    options = subset.Options()
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.glyph_names = True
    options.notdef_outline = True
    options.layout_features = ["*"]          # keep kerning for the wordmark

    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text=WORDMARK)
    subsetter.subset(font)

    rename(font)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    font.save(OUT)

    with open(licence, encoding="utf-8") as src:
        text = src.read()
    with open(LICENCE_OUT, "w", encoding="utf-8", newline="\n") as dst:
        dst.write(text)

    kb = os.path.getsize(OUT) / 1024
    print(f"wrote {OUT} ({kb:.1f} KB)")
    print(f"  glyphs: {', '.join(TTFont(OUT).getGlyphOrder())}")
    print(f"  family: {TTFont(OUT)['name'].getDebugName(1)}")
    print(f"wrote {LICENCE_OUT}")


if __name__ == "__main__":
    main()
