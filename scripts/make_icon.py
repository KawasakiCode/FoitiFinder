"""Draws the two source images in assets/brand/.

Run this, then `flutter pub run flutter_launcher_icons`, which is what turns
these into the mipmap and drawable sets the build actually uses.

    python scripts\\make_icon.py

THE MARK IS ONE LETTER, not the wordmark. "FoitiFinder" is eleven characters
and the icon is read at 48x48 - see the note at the end of
assets/brand/README.md. An "FF" monogram was drawn and rejected for the same
reason: at 48px the two stems merge into one blob.

THE GRADIENT IS THE APP'S. It starts on AppColors.gradientStart and ends on
AppColors.gradientEnd, the same violet-to-pink the wordmark on the login
screen runs through, so the icon and the first screen agree. The background is
violet-950, chosen to sit far enough from the violet end that the purple half
of the glyph still reads against it.

Gluten is a Google font under the OFL. Only the rendered pixels ship, not the
font, so nothing here needs redistributing - but the download has to work for
this script to run.
"""

import math
import os
import sys
import tempfile
import urllib.request

from PIL import Image, ImageDraw, ImageFont

FONT_URL = ("https://github.com/google/fonts/raw/main/ofl/gluten/"
            "Gluten%5Bslnt%2Cwght%5D.ttf")

CANVAS = 1024
GLYPH = "F"

#Gluten is variable: weight 100-900, slant -13..13. 500 is "Medium", the fifth
#of its nine named instances. Heavier closes the counter up - at "Black" the
#aperture of the F nearly seals and the letter reads as a blob at icon size.
WEIGHT = 500
SLANT = 0

BG = (0x2E, 0x10, 0x65)        # violet-950
GRAD_A = (0x7C, 0x3A, 0xED)    # AppColors.gradientStart
GRAD_B = (0xDB, 0x27, 0x77)    # AppColors.gradientEnd, pink-600

#THE SAFE ZONE IS NOT 66/108 OF THIS FILE, which is what every adaptive-icon
#guide will tell you. flutter_launcher_icons wraps the foreground in
#android:inset="16%", so this image is drawn into the middle 68% of the 108dp
#layer rather than across all of it. Sizing the glyph to the 66dp circle here
#applies that margin a second time and leaves the F swimming in a field of
#purple. 66dp of 108 is 626 canvas px; 626 / 0.68 is where it lands in here.
#If the inset in mipmap-anydpi-v26/ic_launcher.xml ever changes, change this.
SAFE_D = 921

#The legacy icon is never cropped by a mask, so its glyph has to be larger to
#look the same size as the adaptive one does inside its circle.
LEGACY_FRACTION = 0.68

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "assets", "brand")


def font_file():
    """Gluten, downloaded once per machine into the system temp directory."""
    path = os.path.join(tempfile.gettempdir(), "Gluten-slnt-wght.ttf")
    if not os.path.exists(path):
        print("downloading Gluten ...")
        urllib.request.urlretrieve(FONT_URL, path)
    if os.path.getsize(path) < 10000:
        sys.exit(f"{path} is too small to be a font; delete it and retry")
    return path


def glyph_mask(px=700):
    """A tight alpha mask of the letter, cropped to its own ink."""
    font = ImageFont.truetype(font_file(), px)
    font.set_variation_by_axes([WEIGHT, SLANT])
    img = Image.new("L", (px * 5, px * 3), 0)
    ImageDraw.Draw(img).text((px, px), GLYPH, font=font, fill=255, anchor="ls")
    return img.crop(img.getbbox())


def centred(mask, height):
    """`mask` scaled to `height` and centred on a CANVAS square."""
    w = max(1, round(mask.width * height / mask.height))
    out = Image.new("L", (CANVAS, CANVAS), 0)
    out.paste(mask.resize((w, height), Image.LANCZOS),
              ((CANVAS - w) // 2, (CANVAS - height) // 2))
    return out, w


def ink_escapes(mask, diameter):
    """True if any ink falls outside the centred circle of `diameter`."""
    ring = Image.new("L", (CANVAS, CANVAS), 255)
    off = (CANVAS - diameter) // 2
    ImageDraw.Draw(ring).ellipse(
        (off, off, off + diameter - 1, off + diameter - 1), fill=0)
    spill = Image.composite(mask, Image.new("L", mask.size, 0), ring)
    return max(spill.getextrema()) > 8


def largest_height_inside(mask, diameter):
    """THE GLYPH IS FITTED BY ITS INK, not by its bounding box. An F is 1.32
    times taller than wide and leaves its bottom-right corner empty, so the
    box-in-circle answer is about 15% smaller than it needs to be."""
    lo, hi = 100, CANVAS
    while hi - lo > 2:
        mid = (lo + hi) // 2
        if ink_escapes(centred(mask, mid)[0], diameter):
            hi = mid
        else:
            lo = mid
    return lo


def gradient(w, h):
    strip = Image.new("RGB", (w, 1))
    px = strip.load()
    for x in range(w):
        t = x / max(w - 1, 1)
        px[x, 0] = tuple(round(a + (b - a) * t) for a, b in zip(GRAD_A, GRAD_B))
    return strip.resize((w, h), Image.NEAREST)


def render(mask, height, background):
    """THE GRADIENT SPANS THE GLYPH, NOT THE CANVAS. Stretched across the whole
    square the letter would only sample the middle of the ramp, and its left
    edge would come out a washed mid-violet rather than the colour the
    wordmark starts on."""
    placed, w = centred(mask, height)
    out = Image.new("RGBA", (CANVAS, CANVAS),
                    (*background, 255) if background else (0, 0, 0, 0))
    ink = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    ink.paste(gradient(w, height).convert("RGBA"),
              ((CANVAS - w) // 2, (CANVAS - height) // 2))
    ink.putalpha(placed)
    out.alpha_composite(ink)
    return out


def main():
    mask = glyph_mask()
    fg_h = largest_height_inside(mask, SAFE_D)

    foreground = os.path.join(OUT_DIR, "icon_foreground.png")
    legacy = os.path.join(OUT_DIR, "icon.png")

    render(mask, fg_h, None).save(foreground)
    render(mask, round(CANVAS * LEGACY_FRACTION), BG).convert("RGB").save(legacy)

    print(f"glyph {GLYPH!r} at weight {WEIGHT}")
    print(f"  foreground height {fg_h}px, ink inside the {SAFE_D}px circle")
    print(f"  wrote {foreground}")
    print(f"  wrote {legacy}")
    print("now run: flutter pub run flutter_launcher_icons")


if __name__ == "__main__":
    main()
