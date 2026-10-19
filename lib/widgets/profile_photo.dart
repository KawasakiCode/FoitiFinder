//One way to put a person's photo on screen, used everywhere one appears.
//
//IT EXISTS BECAUSE THE SAME PHOTO HAD THREE CACHE KEYS. A swipe card drew it
//at memCacheWidth 800, the profile page drew it with no limit, and the deck
//precached it through a bare NetworkImage - three different entries in the
//image cache for one URL, so tapping a card threw away the decoded photo it
//was already showing and decoded it again from scratch. That is the "photo
//turns into the no-photo icon for a split second" on the way into a profile.
//
//THE KEY IS THE PROVIDER, AND memCacheWidth IS PART OF IT. cached_network_image
//hands memCacheWidth to octo_image, which wraps the provider in a ResizeImage
//(octo_image/image.dart), and ResizeImage's equality includes its width. So
//`CachedNetworkImage(memCacheWidth: 1080)` and `CachedNetworkImage()` are
//different images as far as the cache is concerned, and a precache that does
//not match the width is wasted work that also fills the cache with something
//nobody will ask for. profilePhotoProvider builds exactly the same key the
//widget below asks for - use it for every precache.
//
//LOADING IS NOT THE SAME AS MISSING. Both used to draw the same grey box with
//a person in it, which is why a photo on its way in looks exactly like an
//account with no photo. A photo that is coming gets a plain surface; the
//person icon means there is nothing to show.
//
//AND NO CROSS-FADE. The package defaults are a 500ms fade in over a 1000ms
//fade out, so the placeholder hangs around for a full second after a cached
//photo is ready - far more visible than the load it was meant to smooth over.
//Fading from a plain box to a photo buys nothing; it just takes a second.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

//DECODE WIDTH IN PHYSICAL PIXELS, so it is a budget rather than a layout size.
//
//Photos come from a phone camera by way of Firebase Storage, so the file can
//easily be 3000px wide - decoding that at native size is ~48MB of memory for
//ONE image, and six of them on screen will evict everything else in the cache
//(100MB by default) and then be decoded again on the way back. Capping the
//decode is what keeps the cache useful.
//
//1080 covers a full-bleed photo on essentially every phone. Anything smaller
//is visibly soft on a swipe card.
const int kPhotoDecodeWidth = 1080;

//Half-width grid tiles (the likes page) need a quarter of the pixels. Sharing
//the big width would make the flight into a profile seamless, but at six
//tiles on screen that is 40MB of cache for photos the size of a thumbnail.
const int kThumbDecodeWidth = 540;

//Drawn wherever a photo is missing. A LOCAL asset on purpose: the old
//fallback was a picsum URL, which put a random stranger's face beside
//somebody's name and needed the network to do it.
const String kDefaultAvatarAsset = 'assets/images/default_avatar.png';

/// The provider for [url], keyed exactly as [PersonPhoto] asks for it.
///
/// Pass the same `decodeWidth` the widget will use, or the precache warms an
/// entry that nothing ever reads.
ImageProvider profilePhotoProvider(
  String url, {
  int decodeWidth = kPhotoDecodeWidth,
}) {
  return ResizeImage.resizeIfNeeded(
    decodeWidth,
    null,
    CachedNetworkImageProvider(url),
  );
}

/// A photo that is on its way: a plain surface, deliberately not the person
/// icon, so loading cannot be mistaken for "this account has no photo".
class PhotoLoadingBox extends StatelessWidget {
  const PhotoLoadingBox({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

/// There is no photo, or it failed to load. THIS is the one that says so.
///
/// SHOULD BE UNREACHABLE: three photos are required at setup and /photos/sync
/// refuses fewer. It is still drawn properly rather than left as a grey box,
/// because the states that "cannot happen" are the ones nobody looks at - a
/// row written before the rule existed, a Storage object deleted underneath
/// us, or an offline load that fails. The one thing it must never do is show
/// somebody else's face, which is what the old picsum fallback did.
class PhotoMissingBox extends StatelessWidget {
  //kept so a small tile and a full-bleed header can differ
  final double iconSize;

  const PhotoMissingBox({super.key, this.iconSize = 64});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Image.asset(
        kDefaultAvatarAsset,
        fit: BoxFit.cover,
        //the asset is bundled, so a failure here means the bundle itself is
        //wrong - fall back to something that cannot fail
        errorBuilder: (_, _, _) => Center(
          child: Icon(
            Icons.person_outline,
            size: iconSize,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class PersonPhoto extends StatelessWidget {
  final String? url;
  //how wide to decode: kPhotoDecodeWidth for anything full-bleed,
  //kThumbDecodeWidth for grid tiles
  final int decodeWidth;
  final double missingIconSize;
  //Shown while the photo decodes, in place of the plain box. The profile
  //header passes the thumbnail version of the same photo here, which the
  //likes grid has already decoded - so arriving from a tile shows a slightly
  //softer copy of the right photo instead of an empty box.
  final Widget? whileLoading;

  const PersonPhoto({
    super.key,
    required this.url,
    this.decodeWidth = kPhotoDecodeWidth,
    this.missingIconSize = 64,
    this.whileLoading,
  });

  @override
  Widget build(BuildContext context) {
    final address = url;
    if (address == null || address.isEmpty) {
      return PhotoMissingBox(iconSize: missingIconSize);
    }

    return CachedNetworkImage(
      imageUrl: address,
      fit: BoxFit.cover,
      memCacheWidth: decodeWidth,
      //see the note at the top: the defaults leave the placeholder on screen
      //for a second after the photo is ready
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, _) => whileLoading ?? const PhotoLoadingBox(),
      errorWidget: (_, _, _) => PhotoMissingBox(iconSize: missingIconSize),
    );
  }
}
