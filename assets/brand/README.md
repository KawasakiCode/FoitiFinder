# Brand images

Two files belong here, and nothing else references them except
`flutter_launcher_icons` in `pubspec.yaml`.

| file | size | what it is |
|---|---|---|
| `icon.png` | 1024×1024 | the whole icon, edge to edge. Used on Android 7 and below, where there is no adaptive mask. |
| `icon_foreground.png` | 1024×1024 | the artwork **only**, transparent around it, sitting inside the middle ~2/3. |

## Why the foreground is a separate file

Android 8 and up crop every icon to the launcher's own mask — circle,
squircle, teardrop, rounded square, depending on the phone. The system crops
the outer third away and may animate within it. Artwork drawn to the edges of
a 1024 square loses its corners on most devices.

So `icon_foreground.png` should keep everything that matters inside a centred
circle of roughly 666px across, with the rest transparent.

## Generating

```
flutter pub run flutter_launcher_icons
```

That writes every `mipmap-*` density plus the adaptive XML. Commit what it
produces — the generated files are what the build uses, and regenerating is
not part of the build.

## Checking it

The thing to look at is not the 1024 source but the 48×48
`mipmap-mdpi/ic_launcher.png`, because that is the size people actually see.
Detail that reads at 1024 turns to mud there, and an icon that is a small
wordmark in a big field of white is the usual way it happens.
