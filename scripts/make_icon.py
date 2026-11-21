r"""Draws every brand image in assets/brand/: the launcher icon and the logo.

    python scripts\make_icon.py

Then `flutter pub run flutter_launcher_icons`, which turns the two icon files
into the mipmap and drawable sets the build actually uses. The wordmark images
are not consumed by any build step - they are the logo as a picture, for the
places that cannot run Flutter.

TWO ICONS ARE DRAWN AND ONLY ONE IS USED. pubspec.yaml picks; it currently
picks the word. Both are generated every run so that switching is an edit to
that file rather than an edit to this one.

The F exists because "FoitiFinder" is eleven characters and an icon is read at
48x48 - an "FF" monogram was drawn and rejected for the same reason, its two
stems merging into one blob. The word as an icon overrules that on purpose and
pays about 5px of letter height for it; main() prints the number every run.
The wordmark IMAGES are a separate thing again, and are the whole name because
nothing ever shrinks them to 48px.

TWO COLOUR SCHEMES, AND THEY ARE NOT THE SAME ONE. The icon carries the app's
violet-to-pink gradient, AppColors.gradientStart to gradientEnd. The wordmark
carries the policy site's flat pair instead - Foiti in --text, Finder in
--accent - because that is how site/style.css sets it and how AuthBrand sets
it in the app. Changing one to match the other would make the logo disagree
with itself in two places in order to agree in one.

Gluten is a Google font under the OFL. This script only renders pixels, but
the app does bundle a subset of the font - see scripts/make_wordmark_font.py
and the licence that ships beside it.
"""

import math
import os
import sys
import tempfile
import urllib.request

from PIL import Image, ImageChops, ImageDraw, ImageFont

FONT_URL = ("https://github.com/google/fonts/raw/main/ofl/gluten/"
            "Gluten%5Bslnt%2Cwght%5D.ttf")

CANVAS = 1024
GLYPH = "F"

#Gluten is variable: weight 100-900, slant -13..13. 500 is "Medium", the fifth
#of its nine named instances. Heavier closes the counter up - at "Black" the
#aperture of the F nearly seals and the letter reads as a blob at icon size.
WEIGHT = 500
SLANT = 0

GRAD_A = (0x7C, 0x3A, 0xED)    # AppColors.gradientStart
GRAD_B = (0xDB, 0x27, 0x77)    # AppColors.gradientEnd, pink-600

#THE FIELD THE ICON SITS ON, and it is deliberately NOT violet.
#
#It was violet-950 (#2E1065) and that was the bug. Measured, the background
#sat at hue 261 and the gradient's violet end at hue 262 - ONE DEGREE apart.
#They were the same colour at different lightness, so the left of the F
#dissolved into the field (contrast 2.67) while the pink end stood out (3.31)
#and the letter read lopsided rather than lit.
#
#This navy is 33 degrees off the gradient's violet and very dark (lightness
#9.6), so both ends of the mark separate by about the same amount - 3.30 and
#4.09. Five directions were drawn and judged at 48px on light and dark
#wallpapers; a neutral ink was tried on a phone before this.
#
#KNOWN COST: a dark icon on a dark wallpaper has a weak silhouette - the
#circle's own edge stops being visible, which no background-to-mark contrast
#figure catches. That was accepted knowingly.
ICON_BG = (0x0B, 0x10, 0x26)

#The field behind wordmark_violet.png, which is NOT the icon's background and
#no longer tries to be. It is the brand violet that AppColors.gradientStart
#and the policy site's accent both come out of, kept so that lockup still has
#a colour of its own after the icon went neutral.
BRAND_VIOLET = (0x2E, 0x10, 0x65)

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

#THE INSET flutter_launcher_icons WRAPS THE FOREGROUND IN - the 16% from
#mipmap-anydpi-v26/ic_launcher.xml, as a scale. SAFE_D above is already
#divided by it. The wordmark icon needs it spelled out, to work out how big
#the word lands on a screen and give the legacy square a matching size.
INSET_SCALE = 0.68

#The share of the 108dp layer a launcher actually shows.
VISIBLE_FRACTION = 72 / 108

#HOW MUCH OF THAT ROOM THE LETTER ACTUALLY TAKES. SAFE_D and LEGACY_FRACTION
#are geometry - where the launcher is guaranteed not to crop. This is the
#judgement on top of it, and it is NOT a guess any more.
#
#IT IS SET AGAINST THE REST OF THE HOME SCREEN. A screenshot of this icon
#beside Gmail was measured: Gmail's M fills 56.0% of its disc's height, and
#this F filled 76.5% of its own, which is why it looked oversized next to
#everything around it. Platform icons leave far more air than they appear to.
#
#Working back through the pipeline - a glyph of height h in this file is
#inset to h * INSET_SCALE and then shown inside the visible 72/108 of the
#layer - 56% of the disc means 562px of this 1024 canvas, which is 0.671 of
#the 838px that fits the safe circle.
#
#It multiplies BOTH sizes, so the adaptive and legacy icons stay the same size
#as each other - changing only one is how they drift apart.
GLYPH_FILL = 0.671

# ---- the wordmark images ----

WORDMARK_HEAD = "Foiti"     # --text on the policy site
WORDMARK_TAIL = "Finder"    # --accent, the half that carries the colour

#site/style.css, both halves of its prefers-color-scheme split. Named for the
#background they are meant to sit on, not for the colour they are.
INK_FOR_LIGHT = (0x1B, 0x17, 0x25)
ACCENT_FOR_LIGHT = (0x6C, 0x3F, 0xD4)
INK_FOR_DARK = (0xEC, 0xE8, 0xF4)
ACCENT_FOR_DARK = (0xB7, 0x9B, 0xFF)

#How wide the lettering itself is drawn. The file comes out wider by the
#padding - these are logos, so they are wide rather than tall and a fixed
#width is the useful thing to fix.
WORDMARK_WIDTH = 1600

#HOW MUCH IS TAKEN OUT OF EVERY GAP, as a fraction of the em, so it holds at
#any render size. Gluten sets this name loosely for a logo: at its own spacing
#the tightest pairs ("nd", "de") leave a gap of 29/400ths of the em and the
#widest ("iF", "Fo") leave 54, which reads as a sentence rather than a mark.
#
#THE TIGHTEST PAIR IS WHAT THIS IS SET BY, not the average - taking 0.0525 em
#out leaves "nd" and "de" at 8/400ths and every other pair wider, which is the
#"almost touching" end of still having a gap. Past about 0.065 em those two
#pairs collide and the word turns into one connected shape. Tracking applies
#between letters and not inside them, so widening this does not thin the ink;
#it only closes the holes. See the gap table in assets/brand/README.md.
TRACKING = 0.0525

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


def wordmark_masks(px=400):
    """The two halves, as masks on one shared canvas.

    DRAWN SEPARATELY AND NOT CUT IN TWO. Colouring a single rendered string by
    slicing it at an x position looks equivalent and is not: Gluten's F leans
    its top arm back over the letter before it, so a vertical cut through the
    boundary takes a slice of the F and paints it the other colour. Drawing
    each half at its own measured offset keeps every letter whole.

    ONE LETTER AT A TIME, because TRACKING has to come out of each gap and
    PIL has no letter-spacing. Each letter is placed at the advance width of
    everything before it, less what the tracking has already closed up.

    That is exact only because this string has no kern pairs in Gluten: the
    advance of the whole word equals the sum of its letters', so at TRACKING=0
    this draws precisely what one text() call draws. A font that kerned would
    need the pair adjustments putting back by hand.
    """
    font = ImageFont.truetype(font_file(), px)
    font.set_variation_by_axes([WEIGHT, SLANT])

    word = WORDMARK_HEAD + WORDMARK_TAIL
    rule = ImageDraw.Draw(Image.new("L", (1, 1)))
    track = px * TRACKING

    size = (int(rule.textlength(word, font=font)) + px * 2, px * 3)
    masks = [Image.new("L", size, 0), Image.new("L", size, 0)]
    for i, letter in enumerate(word):
        half = 0 if i < len(WORDMARK_HEAD) else 1
        x = rule.textlength(word[:i], font=font) - i * track
        ImageDraw.Draw(masks[half]).text((px + x, px * 2), letter,
                                         font=font, fill=255, anchor="ls")
    return masks


def wordmark(ink, accent, background, pad_fraction):
    """The logo at WORDMARK_WIDTH, padded, on `background` or on nothing."""
    head, tail = wordmark_masks()

    #cropped to the two together, so both keep the same origin and the
    #baseline does not shift between the halves
    box = ImageChops.lighter(head, tail).getbbox()
    head, tail = head.crop(box), tail.crop(box)

    height = max(1, round(head.height * WORDMARK_WIDTH / head.width))
    head = head.resize((WORDMARK_WIDTH, height), Image.LANCZOS)
    tail = tail.resize((WORDMARK_WIDTH, height), Image.LANCZOS)

    pad = round(height * pad_fraction)
    out = Image.new("RGBA", (WORDMARK_WIDTH + pad * 2, height + pad * 2),
                    (*background, 255) if background else (0, 0, 0, 0))
    for mask, colour in ((head, ink), (tail, accent)):
        layer = Image.new("RGBA", (WORDMARK_WIDTH, height), (*colour, 255))
        layer.putalpha(mask)
        out.alpha_composite(layer, (pad, pad))
    return out


def wordmark_icon(background):
    """The whole name on a CANVAS square, to be used as the launcher icon.

    THE WORD IS 7.5 TIMES WIDER THAN IT IS TALL, and a launcher icon is
    square. Fitting all of it in means the width runs out first and the
    letters end up a few pixels tall on a real home screen - main() prints the
    number. That is a known cost of showing the whole name rather than the F,
    not an oversight; see "The word as the icon" in assets/brand/README.md.

    TWO DIFFERENT SIZES FOR THE SAME APPARENT RESULT. The foreground is inset
    by 16% and then cropped to the visible 72/108 of the layer before anyone
    sees it, while the legacy square is shown whole. Giving both the same
    width in the file would make the legacy icon's word look markedly bigger.
    """
    head, tail = wordmark_masks()

    #cropped to the two together, so the halves keep one origin
    box = ImageChops.lighter(head, tail).getbbox()
    head, tail = head.crop(box), tail.crop(box)
    ratio = head.width / head.height

    #the largest w x h of this shape that fits inside the safe circle:
    #w^2 + h^2 = D^2 with h = w / ratio
    fitted = SAFE_D / math.sqrt(1 + 1 / ratio ** 2) * GLYPH_FILL

    if background is None:
        width = fitted
    else:
        visible = CANVAS * VISIBLE_FRACTION
        width = fitted * INSET_SCALE / visible * CANVAS

    width = round(width)
    height = max(1, round(width / ratio))
    head = head.resize((width, height), Image.LANCZOS)
    tail = tail.resize((width, height), Image.LANCZOS)

    out = Image.new("RGBA", (CANVAS, CANVAS),
                    (*background, 255) if background else (0, 0, 0, 0))
    at = ((CANVAS - width) // 2, (CANVAS - height) // 2)
    for mask, colour in ((head, INK_FOR_DARK), (tail, ACCENT_FOR_DARK)):
        layer = Image.new("RGBA", (width, height), (*colour, 255))
        layer.putalpha(mask)
        out.alpha_composite(layer, at)
    return out, height


def main():
    mask = glyph_mask()
    fits = largest_height_inside(mask, SAFE_D)
    fg_h = round(fits * GLYPH_FILL)
    legacy_h = round(CANVAS * LEGACY_FRACTION * GLYPH_FILL)

    foreground = os.path.join(OUT_DIR, "icon_foreground.png")
    legacy = os.path.join(OUT_DIR, "icon.png")

    render(mask, fg_h, None).save(foreground)
    render(mask, legacy_h, ICON_BG).convert("RGB").save(legacy)

    print(f"icon: glyph {GLYPH!r} at weight {WEIGHT}")
    print(f"  foreground height {fg_h}px - {GLYPH_FILL} of the {fits}px that "
          f"fits the {SAFE_D}px circle")
    print(f"  legacy height {legacy_h}px")
    print(f"  wrote {foreground}")
    print(f"  wrote {legacy}")

    #THREE, BECAUSE A LOGO HAS TO LAND ON SOMETHING. The transparent pair is
    #the same word in the two colour schemes the site defines; which one you
    #want depends entirely on what is behind it, and getting that wrong is how
    #a logo ends up invisible in a README on a dark theme. The third is the
    #lockup: the dark pair on the brand violet, for when there is no
    #background to sit on and the logo has to bring its own.
    for name, ink, accent, bg, pad in (
            ("wordmark_on_light", INK_FOR_LIGHT, ACCENT_FOR_LIGHT, None, 0.18),
            ("wordmark_on_dark", INK_FOR_DARK, ACCENT_FOR_DARK, None, 0.18),
            ("wordmark_violet", INK_FOR_DARK, ACCENT_FOR_DARK, BRAND_VIOLET, 0.45),
    ):
        path = os.path.join(OUT_DIR, f"{name}.png")
        image = wordmark(ink, accent, bg, pad)
        (image.convert("RGB") if bg else image).save(path)
        print(f"wordmark: wrote {path}  {image.width}x{image.height}")

    #THE WHOLE NAME AS THE ICON, the alternative to the F. Both sets are kept
    #so the choice is a two line edit in pubspec.yaml rather than a rerun with
    #different constants.
    for name, bg in (("icon_wordmark_foreground", None),
                     ("icon_wordmark", ICON_BG)):
        path = os.path.join(OUT_DIR, f"{name}.png")
        image, letters = wordmark_icon(bg)
        (image.convert("RGB") if bg else image).save(path)
        if bg is None:
            #what the ink measures on a 48px launcher, which is the number
            #that decides whether this is readable
            on_screen = (letters * INSET_SCALE
                         / (CANVAS * VISIBLE_FRACTION) * 48)
            print(f"wordmark icon: lettering {letters}px of {CANVAS} "
                  f"- about {on_screen:.1f}px tall on a 48px launcher")
        print(f"  wrote {path}")

    print("now run: flutter pub run flutter_launcher_icons")


if __name__ == "__main__":
    main()
