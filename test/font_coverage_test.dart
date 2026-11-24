//The bundled font must contain every character the app can display.
//
//A MISSING GLYPH IS NOT AN ERROR AT RUNTIME. Flutter asks the operating system
//for a substitute and draws that instead, so the text still appears - in a
//different typeface, at a different weight, or as tofu boxes on a device with
//no substitute. Which one you get depends on the device, which is why this
//went unnoticed: the Greek UI was being rendered by whatever each phone and
//emulator happened to have installed.
//
//That is what this test prevents. It reads the actual .ttf we ship, parses its
//character map, and checks it against every string in both .arb files. Adding
//a Greek string, an accented name or a symbol the font cannot draw fails here
//instead of on someone's phone.
//
//Parsing the font by hand rather than with a package: the character map is two
//well-documented table formats, and a dependency for one test is not worth it.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

//INTER IS THE ONLY FACE IN THE APP AND HAS NO FALLBACK BEHIND IT, which is
//what makes this test the whole of the guarantee. There used to be a second
//bundled font (Gluten, for a look) with Inter underneath it as the last link
//in the chain; now there is one link, and if a string needs a glyph this file
//does not carry, the phone's own fonts are what draw it.
const String _fontPath = 'assets/fonts/Inter.ttf';
const List<String> _arbFiles = ['lib/l10n/app_en.arb', 'lib/l10n/app_el.arb'];

void main() {
  late Set<int> covered;

  setUpAll(() {
    covered = _codepointsIn(File(_fontPath).readAsBytesSync());
  });

  test('the bundled font exists and maps a sane number of characters', () {
    expect(File(_fontPath).existsSync(), isTrue, reason: '$_fontPath is gone');
    //a Latin-only font is around 700; anything near that means Greek is absent
    expect(covered.length, greaterThan(1000));
  });

  test('Greek is actually in the font', () {
    //a handful of everyday letters, including the accented ones Greek uses
    //constantly and that a Latin font would never carry
    for (final ch in 'αβγδεζηθικλμνξοπρςστυφχψωάέήίόύώΑΒΓΔΩ'.split('')) {
      expect(
        covered.contains(ch.codeUnitAt(0)),
        isTrue,
        reason: 'the font cannot draw "$ch"',
      );
    }
  });

  for (final path in _arbFiles) {
    test('every character in $path can be drawn', () {
      final Map<String, dynamic> arb = jsonDecode(
        File(path).readAsStringSync(),
      );

      //key -> the characters it needs that the font does not have
      final missing = <String, String>{};
      arb.forEach((key, value) {
        //@-prefixed entries are metadata (placeholder types), not shown text
        if (key.startsWith('@') || value is! String) return;
        final gaps = value.runes
            .where((r) => !covered.contains(r))
            //placeholders like {count} are substituted at runtime; their
            //braces are ASCII and covered anyway
            .map(String.fromCharCode)
            .toSet();
        if (gaps.isNotEmpty) missing[key] = gaps.join();
      });

      expect(
        missing,
        isEmpty,
        reason:
            'these strings need glyphs $_fontPath does not have:\n'
            '${missing.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}',
      );
    });
  }

  //THE LICENCE HAS TO SHIP WITH THE FONT.
  //
  //Inter is under the SIL OFL, whose clause 2 lets it be "bundled,
  //redistributed and/or sold with any software, provided that each copy
  //contains the above copyright notice and this license". The 874 KB .ttf
  //inside the APK is such a copy, so the text has to be in there too.
  //
  //ALL THREE WAYS THIS BREAKS ARE SILENT. The asset path in main.dart is a
  //string; the pubspec entry is a separate string; and the licence screen is
  //a place nobody looks. Delete the file, drop the pubspec line, or typo
  //either, and the app builds, runs, and quietly distributes the font with no
  //licence attached.
  group('the font licence', () {
    const String licencePath = 'assets/fonts/OFL-Inter.txt';

    test('ships beside the font', () {
      expect(File(licencePath).existsSync(), isTrue,
          reason: '$licencePath is gone, and $_fontPath is still bundled');
    });

    test('is the OFL, naming Inter as the copyright holder', () {
      final String text = File(licencePath).readAsStringSync();
      //the notice clause 2 requires, not just any licence text
      expect(text, contains('Copyright'));
      expect(text, contains('The Inter Project Authors'));
      expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
      //the operative clause itself, so a truncated file fails here
      expect(text, contains('PERMISSION AND CONDITIONS'));
      expect(text, contains('DISCLAIMER'));
    });

    test('is bundled by pubspec.yaml', () {
      //being on disk is not being in the APK: an asset Flutter was never told
      //about is not shipped, and rootBundle.loadString then throws at runtime
      //on the licence screen only.
      expect(File('pubspec.yaml').readAsStringSync(), contains(licencePath));
    });

    test('and main.dart registers it against the family it covers', () {
      //LicenseRegistry entries are keyed by family name, and 'Inter' is what
      //AppTheme.fontFamily sets. Registering it under any other string files
      //the licence against a font the app does not use.
      final String main = File('lib/main.dart').readAsStringSync();
      expect(main, contains(licencePath),
          reason: 'main.dart no longer loads the licence text');
      expect(main, contains("<String>['Inter']"),
          reason: 'the licence is not registered against the Inter family');
    });
  });
}

//Every codepoint the font can draw, read out of its `cmap` table.
//
//A TrueType file is a directory of tables. `cmap` holds one subtable per
//encoding; we merge them all, since any of them being able to draw a
//character is enough. Only formats 4 (16-bit) and 12 (full Unicode) are
//handled - between them they cover every font in practical use.
Set<int> _codepointsIn(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final tableCount = data.getUint16(4);

  int? cmapOffset;
  for (var i = 0; i < tableCount; i++) {
    final entry = 12 + 16 * i;
    final tag = String.fromCharCodes(bytes.sublist(entry, entry + 4));
    if (tag == 'cmap') cmapOffset = data.getUint32(entry + 8);
  }
  if (cmapOffset == null) throw StateError('font has no cmap table');

  final result = <int>{};
  final subtableCount = data.getUint16(cmapOffset + 2);

  for (var i = 0; i < subtableCount; i++) {
    final record = cmapOffset + 4 + 8 * i;
    final subtable = cmapOffset + data.getUint32(record + 4);
    final format = data.getUint16(subtable);

    if (format == 4) {
      final segCountX2 = data.getUint16(subtable + 6);
      final segCount = segCountX2 ~/ 2;
      final endsAt = subtable + 14;
      final startsAt = endsAt + segCountX2 + 2;
      for (var s = 0; s < segCount; s++) {
        final end = data.getUint16(endsAt + s * 2);
        final start = data.getUint16(startsAt + s * 2);
        //0xFFFF is the required terminator segment, not a real range
        if (end == 0xFFFF) continue;
        for (var c = start; c <= end; c++) {
          result.add(c);
        }
      }
    } else if (format == 12) {
      final groups = data.getUint32(subtable + 12);
      for (var g = 0; g < groups; g++) {
        final at = subtable + 16 + 12 * g;
        final start = data.getUint32(at);
        final end = data.getUint32(at + 4);
        //stop at the end of the multilingual planes: nothing in this app
        //reaches there, and the ranges can be enormous
        for (var c = start; c <= end && c <= 0x2FFFF; c++) {
          result.add(c);
        }
      }
    }
  }

  return result;
}
