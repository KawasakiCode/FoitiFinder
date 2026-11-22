r"""Builds the Gluten faces the whole app can be set in.

    python scripts\make_app_font.py

THIS IS NOT THE LOGO FONT. scripts/make_wordmark_font.py cuts Gluten down to
the eight letters of "FoitiFinder" for the wordmark. This keeps the whole
character set, because it has to set every string in the app and anything a
user types into a name or a bio.

ONE FILE PER WEIGHT, AND NOT THE VARIABLE FONT. Flutter does not drive a
variable font's wght axis from TextStyle.fontWeight - a variable file declared
in pubspec.yaml renders at its default instance, and Gluten's default is 100.
Declaring the variable file would set the entire app in Thin. So each weight
the app actually asks for is pinned to its own static file.

GLUTEN HAS NO GREEK. It covers the English strings completely and misses the
whole Greek alphabet - 63 of the 121 characters in app_el.arb. That is why
AppTheme carries a fontFamilyFallback of Inter: Greek is drawn by a font that
is bundled and known, rather than by whatever each phone happens to own.
test/font_coverage_test.dart checks the pair together.

LICENCE. Gluten is under the SIL OFL 1.1, the same licence as the wordmark
subset, and assets/fonts/OFL-Gluten.txt already ships with it.
"""

import os
import sys
import tempfile
import urllib.request

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

FONT_URL = ("https://github.com/google/fonts/raw/main/ofl/gluten/"
            "Gluten%5Bslnt%2Cwght%5D.ttf")

FAMILY = "Gluten"
SLANT = 0

#Every weight lib/ asks for. Flutter snaps an unlisted weight to the nearest
#listed one, so a missing 600 does not fail - it quietly draws as 700.
WEIGHTS = {
    400: "Regular",
    500: "Medium",
    600: "SemiBold",
    700: "Bold",
    800: "ExtraBold",
}

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "fonts")


def download(url, path, minimum):
    if not os.path.exists(path):
        print(f"downloading {os.path.basename(path)} ...")
        urllib.request.urlretrieve(url, path)
    if os.path.getsize(path) < minimum:
        sys.exit(f"{path} is too small to be right; delete it and retry")
    return path


def rename(font, style):
    """THE INSTANCER DOES NOT REVISIT THE NAME TABLE, so every instance comes
    out claiming to be "Gluten Thin" - the variable default. Flutter reads the
    family from pubspec.yaml rather than from here, but a font that lies about
    its own weight costs somebody an afternoon."""
    for record in font["name"].names:
        nid = record.nameID
        if nid == 1:
            record.string = FAMILY
        elif nid == 2:
            record.string = style
        elif nid == 4:
            record.string = f"{FAMILY} {style}"
        elif nid == 6:
            record.string = f"{FAMILY}-{style}"
        elif nid == 16:
            record.string = FAMILY
        elif nid == 17:
            record.string = style


def main():
    variable = download(FONT_URL,
                        os.path.join(tempfile.gettempdir(),
                                     "Gluten-slnt-wght.ttf"), 10000)
    os.makedirs(OUT_DIR, exist_ok=True)

    total = 0
    for weight, style in sorted(WEIGHTS.items()):
        font = TTFont(variable)
        instancer.instantiateVariableFont(
            font, {"wght": weight, "slnt": SLANT},
            inplace=True, updateFontNames=False)
        rename(font, style)

        out = os.path.join(OUT_DIR, f"{FAMILY}-{style}.ttf")
        font.save(out)
        kb = os.path.getsize(out) / 1024
        total += kb
        print(f"wrote {out} ({kb:.1f} KB)  wght {weight}, "
              f"{len(TTFont(out).getBestCmap())} codepoints")

    print(f"{len(WEIGHTS)} faces, {total:.0f} KB in all")
    print("declare them in pubspec.yaml under the Gluten family")


if __name__ == "__main__":
    main()
