# Brand images

Two kinds of thing live here: launcher icons, which the Android build consumes
through `flutter_launcher_icons` in `pubspec.yaml`, and the logo as a picture,
which nothing consumes automatically.

**There are two icons and only one of them is in use.** The F and the whole
word are both generated every run; `pubspec.yaml` decides which the build
takes. It takes the F — the word was tried on a phone and could not be read
at icon size. See "The word as the icon" below.

| file | size | what it is |
|---|---|---|
| `icon.png` | 1024×1024 | the whole icon, edge to edge. Used on Android 7 and below, where there is no adaptive mask. |
| `icon_foreground.png` | 1024×1024 | the artwork **only**, transparent around it. |
| `icon_wordmark.png` | 1024×1024 | the whole name as a square icon. The legacy half of the pair. |
| `icon_wordmark_foreground.png` | 1024×1024 | the same, transparent, for the adaptive layer. |
| `wordmark_on_light.png` | 1676×289 | the logo for a light background. Transparent. |
| `wordmark_on_dark.png` | 1676×289 | the same logo for a dark background. Transparent. |
| `wordmark_violet.png` | 1792×405 | the logo on the brand violet, for when there is no background to sit on. Opaque. |

All seven are drawn by `scripts/make_icon.py` rather than by hand, so do not
edit them in an image editor — the next run overwrites whatever you did. Change
the constants at the top of that script instead.

**The two transparent files are named for what goes behind them, not for the
colour of the ink.** `wordmark_on_light` is the near-black one. Picking by the
file name rather than by opening it is how a logo ends up invisible against a
README on someone's dark theme.

## The F icon

A single **F** in [Gluten](https://fonts.google.com/specimen/Gluten) at weight
500 (`Medium`, the fifth of its nine named instances), filled with the app's
own violet-to-pink gradient, on a deep navy field (`#0B1026`).

- **One letter, not the wordmark.** "FoitiFinder" is eleven characters and
  this is read at 48×48. An `FF` monogram was drawn and rejected for the same
  reason: at icon size the two stems merge into one blob. The whole word was
  tried against this argument on a real phone, and lost.
- **Weight 500 and not heavier.** Gluten is already a fat rounded face.
  By `Black` the counter of the F has nearly closed and the letter reads as a
  shape rather than a letter.
- **The gradient is spanned across the glyph, not the canvas.** Stretched
  across the whole square, a centred letter only samples the middle of the
  ramp and its left edge comes out a washed mid-violet instead of
  `AppColors.gradientStart`.
- **The background is neutral, and it used to be violet-950.** That was a
  real bug, found by measuring rather than by squinting: `#2E1065` sits at
  hue 261 and the gradient's violet end at hue 262 — **one degree apart**.
  They were one colour at two lightnesses, so the left of the F dissolved
  into the field (contrast 2.67) while the pink end stood out (3.31), and
  the letter read lopsided. The navy sits 33 degrees off that violet and is
  very dark (lightness 9.6), so both ends separate by roughly the same
  amount (3.30 and 4.09).
- **What ink costs.** A dark icon on a dark wallpaper has a weak silhouette:
  the circle's own edge stops being visible. No background-to-mark contrast
  figure catches that, because the wallpaper is not in the comparison. Four
  other directions — navy, light, a gradient field with the letter knocked
  out, and a corrected violet — were drawn and judged at 48px on both
  wallpapers before this was chosen over them.

## Why the foreground is a separate file

Android 8 and up crop every icon to the launcher's own mask — circle,
squircle, teardrop, rounded square, depending on the phone. The system crops
the outer third away and may animate within it. Artwork drawn to the edges of
a 1024 square loses its corners on most devices.

### The safe zone is **not** 66/108 of this file

Which is what every adaptive-icon guide will tell you, and it is wrong here.
`flutter_launcher_icons` wraps the foreground in `android:inset="16%"` — look
at `mipmap-anydpi-v26/ic_launcher.xml` — so this image is drawn into the
middle 68% of the 108dp layer rather than across all of it.

Size the glyph to the 66dp circle *in this file* and the margin is applied
twice: the result is a small letter swimming in a field of purple, which is
exactly the failure the last section of this file warns about. It happened on
the first pass.

66dp of 108 is 626 canvas px, so the usable circle **within this file** is
`626 / 0.68` ≈ 921px. `make_icon.py` fits the glyph to that, and fits it by
its *ink* rather than its bounding box — an F is 1.32× taller than wide and
leaves its bottom-right corner empty, so the box-in-circle answer comes out
about 15% smaller than it needs to be.

If that inset ever changes, change `SAFE_D` in the script with it.

### Fitting that circle is not the same as filling it

`SAFE_D` says where the launcher is guaranteed not to crop. `GLYPH_FILL` is
the separate judgement of how much of that room the mark should take, and it
is `0.671` — the letter is drawn at 67% of the largest size that fits.

Those are two different questions and they are kept apart on purpose: one is
geometry, the other is taste, and only one of them changes when a launcher
changes its mask.

**That 0.671 is measured, not chosen.** It was `0.92` and the icon looked
oversized on a real home screen. A screenshot of it beside Gmail settled it:

| | glyph height as a share of the disc |
|---|---|
| Gmail's `M` | 56.0% |
| our `F` at `GLYPH_FILL = 0.92` | 76.5% |
| our `F` at `GLYPH_FILL = 0.671` | 56.0% |

Platform icons leave far more air than they look like they do, and an icon
drawn to fill its safe circle will sit next to them looking wrong without
anything being measurably wrong with it.

The arithmetic, if the target ever changes: a glyph of height `h` in this file
is inset to `h × INSET_SCALE` and then shown inside the visible 72/108 of the
layer, so a share `k` of the disc means `h = k × 1024 × (72/108) ÷ 0.68`, and
`GLYPH_FILL` is that over the 838px that fits the safe circle.

`GLYPH_FILL` multiplies the adaptive and the legacy sizes together, so the two
icons cannot drift apart by someone adjusting one of them.

## The word as the icon

`pubspec.yaml` pointed the build at `icon_wordmark*.png` — the whole name
rather than the F — and it was tried on a phone and rejected. The files are
still generated, and this is the record of why they are not used.

**What it costs.** The word is **7.5 times wider than it is tall**. A launcher
icon is square and the usable part of it is a circle, so fitting all of the
name in is a width-limited fit: the lettering comes out 112px of the 1024
canvas, which is about **5px tall on a 48px home screen**. The name is all
there and it is not readable at that size. That is the trade, and it is the
reason `What the mark is` above argues for one letter.

**The two files are not the same size, deliberately.** The foreground is inset
by 16% and then cropped to the visible 72/108 of the layer before anybody sees
it; the legacy square is shown whole. Giving both the same width in the file
would make the legacy icon's word look noticeably bigger than the adaptive
one's. `wordmark_icon()` sizes the foreground to the safe circle and then
works backwards from what lands on screen to size the legacy square to match.

**Going back to the F** is three lines in `pubspec.yaml` — `image_path` to
`icon.png`, both adaptive layers to `icon_foreground.png` — and a rerun. Both
sets are generated every time, so neither has to be rebuilt first.

## The wordmark images

The whole name, in Gluten at the same weight as the icon, split where the
policy site splits it: `Foiti` in the site's `--text`, `Finder` in its
`--accent`. Those are the colours in `site/style.css`, both halves of its
light/dark pair, and the same ones `AuthBrand` sets in the app — so the logo
is one mark in all three places.

**It does not carry the icon's gradient.** The icon is violet-to-pink; the
wordmark is the site's flat pair. That is a deliberate split rather than an
oversight: matching them would mean changing the logo in the app and on the
policy site to agree with the icon, which is the wrong way round.

**The halves are drawn separately, not cut out of one rendering.** Gluten's
`F` leans its top arm back over the letter before it, so slicing a single
rendered string at the boundary takes a slice of the `F` with it and paints it
the wrong colour. Each half is drawn at its own measured offset instead.

**The letters are tracked in by 0.0525 em.** Gluten spaces this name for
reading rather than for a logo, and at its own spacing the word looks like a
sentence. `TRACKING` in the script takes the same fraction of the em out of
every gap — measured ink to ink over the rows the two letters share, which is
the only honest way to measure a face whose `F` reaches backwards:

| pair | Gluten's spacing | tracked in |
|---|---|---|
| `Fo` | 53 | 32 |
| `oi` | 39 | 18 |
| `it` | 48 | 27 |
| `ti` | 42 | 21 |
| `iF` | 54 | 33 |
| `Fi` | 38 | 17 |
| `in` | 50 | 29 |
| `nd` | **29** | **8** |
| `de` | **29** | **8** |
| `er` | 39 | 18 |

In 400ths of the em. **`nd` and `de` are what the number is set by** — they
are already the tightest pairs by a margin of ten, so they close first, and
past about 0.065 em they touch and the word becomes one joined shape.

`AuthBrand` carries the same 0.0525 as a `letterSpacing` of −2.1 at its 40pt.
Change one and change the other, or the login screen stops matching every
picture of the logo.

**In the app, do not use these.** `AuthBrand` sets the logo as live text in a
4.5 KB subset of the font — see `scripts/make_wordmark_font.py`. That stays
sharp at any size and follows the theme; a bitmap would need two files and
would still be wrong at the third size somebody uses it at. These images are
for everywhere that cannot run Flutter.

## Generating

```
python scripts\make_icon.py
flutter pub run flutter_launcher_icons
```

The first writes all seven images here. The second turns whichever icon pair
`pubspec.yaml` names into every `mipmap-*` and `drawable-*` density, the
adaptive XML, and `values/colors.xml` holding the background colour. It reads
only those two files, so skip it when the change was to the other icon or to
the three `wordmark_on_*`/`wordmark_violet` pictures, which no build step
consumes. Commit what it produces — the generated files are what the build
uses, and regenerating is not part of the build.

## Checking it

The thing to look at is not the 1024 source but the 48×48
`mipmap-mdpi/ic_launcher.png`, because that is the size people actually see.
Detail that reads at 1024 turns to mud there, and an icon that is a small
wordmark in a big field is the usual way it happens.

**The wordmark icon fails that test on purpose**, so do not read its 48×48 as
a bug to fix by making the letters bigger — they cannot be made bigger without
cropping the name. If what you see there is not wanted, the fix is the F.

Checking the adaptive icon means compositing it yourself: background colour,
then the foreground inset by 16%, then crop to the middle 72 of 108dp, then
mask to a circle. Opening `icon_foreground.png` on its own tells you very
little about what a phone will show.
