# Brand images

Two files belong here, and nothing else references them except
`flutter_launcher_icons` in `pubspec.yaml`.

| file | size | what it is |
|---|---|---|
| `icon.png` | 1024×1024 | the whole icon, edge to edge. Used on Android 7 and below, where there is no adaptive mask. |
| `icon_foreground.png` | 1024×1024 | the artwork **only**, transparent around it. |

Both are drawn by `scripts/make_icon.py` rather than by hand, so do not edit
them in an image editor — the next run overwrites whatever you did. Change the
constants at the top of that script instead.

## What the mark is

A single **F** in [Gluten](https://fonts.google.com/specimen/Gluten) at weight
500 (`Medium`, the fifth of its nine named instances), filled with the app's
own violet-to-pink gradient, on a violet-950 field.

- **One letter, not the wordmark.** "FoitiFinder" is eleven characters and
  this is read at 48×48. An `FF` monogram was drawn and rejected for the same
  reason: at icon size the two stems merge into one blob.
- **Weight 500 and not heavier.** Gluten is already a fat rounded face.
  By `Black` the counter of the F has nearly closed and the letter reads as a
  shape rather than a letter.
- **The gradient is spanned across the glyph, not the canvas.** Stretched
  across the whole square, a centred letter only samples the middle of the
  ramp and its left edge comes out a washed mid-violet instead of
  `AppColors.gradientStart`.
- **The background is deliberately far from the gradient's violet end.**
  `#2E1065` against a mark that begins at `#7C3AED`. A background any nearer
  swallows the purple half of the letter.

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

## Generating

```
python scripts\make_icon.py
flutter pub run flutter_launcher_icons
```

The second command writes every `mipmap-*` and `drawable-*` density, the
adaptive XML, and `values/colors.xml` holding the background colour. Commit
what it produces — the generated files are what the build uses, and
regenerating is not part of the build.

## Checking it

The thing to look at is not the 1024 source but the 48×48
`mipmap-mdpi/ic_launcher.png`, because that is the size people actually see.
Detail that reads at 1024 turns to mud there, and an icon that is a small
wordmark in a big field of white is the usual way it happens.

Checking the adaptive icon means compositing it yourself: background colour,
then the foreground inset by 16%, then crop to the middle 72 of 108dp, then
mask to a circle. Opening `icon_foreground.png` on its own tells you very
little about what a phone will show.
