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
