//The cache key is the whole point of profile_photo.dart.
//
//A photo shown at one decode width and precached at another is two entries in
//the image cache, so the precache is wasted AND the photo is decoded again the
//moment it is shown somewhere else - which looked like the photo turning into
//the no-photo icon for a frame on the way into a profile.
//
//These assert the framework behaviour the design depends on: ResizeImage's
//identity includes its width, so the width has to match everywhere.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/widgets/profile_photo.dart';

const String _url = 'https://example.com/photo.jpg';

void main() {
  test('the same url and width is the same cache entry', () {
    expect(profilePhotoProvider(_url), profilePhotoProvider(_url));
    expect(
      profilePhotoProvider(_url).hashCode,
      profilePhotoProvider(_url).hashCode,
    );
  });

  test('a different decode width is a DIFFERENT cache entry', () {
    //the trap: this is why a card at 800 and a header at full size decoded the
    //same photo twice
    expect(
      profilePhotoProvider(_url, decodeWidth: kPhotoDecodeWidth),
      isNot(profilePhotoProvider(_url, decodeWidth: kThumbDecodeWidth)),
    );
  });

  test('the provider carries the decode width rather than dropping it', () {
    //a ResizeImage wrapper is what caps the decode; without it a 3000px photo
    //is decoded at native size
    final provider = profilePhotoProvider(_url);
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).width, kPhotoDecodeWidth);
  });

  test('full-bleed decodes wider than a grid thumbnail', () {
    expect(kPhotoDecodeWidth, greaterThan(kThumbDecodeWidth));
  });
}
