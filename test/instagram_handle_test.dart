//The same cases as backend/tests/test_instagram.py, on purpose: the two
//normalisers have to agree, or the app shows one handle and the column holds
//another.

import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/utils/instagram_handle.dart';

void main() {
  group('every way of writing the same handle', () {
    const inputs = [
      'maria.pap',
      '@maria.pap',
      '  maria.pap  ',
      'MARIA.PAP',
      'instagram.com/maria.pap',
      'www.instagram.com/maria.pap',
      'https://www.instagram.com/maria.pap/',
      'https://instagram.com/maria.pap?igsh=MXY2bGJ0',
      'HTTPS://Instagram.com/Maria.Pap',
      'instagram.com/maria.pap#',
    ];

    for (final raw in inputs) {
      test('"$raw"', () {
        expect(normaliseInstagramHandle(raw), 'maria.pap');
      });
    }
  });

  test('underscores and digits survive', () {
    expect(normaliseInstagramHandle('_nikos_99'), '_nikos_99');
  });

  group('nothing is not a handle', () {
    for (final raw in [null, '', '   ', '@', 'instagram.com/']) {
      test('"$raw"', () => expect(normaliseInstagramHandle(raw), isNull));
    }
  });

  group('shapes that cannot be a handle', () {
    const bad = [
      'maria pap', // spaces
      'maria-pap', // hyphens
      'maria@pap', // an @ anywhere but the front
      'maria/pap', // a deeper path is not a profile
      '.maria', // leading full stop
      'maria.', // trailing full stop
      'maria..pap', // two in a row
      'maria@uom.edu.gr', // an email typed into a username field
    ];

    for (final raw in bad) {
      test('"$raw"', () => expect(normaliseInstagramHandle(raw), isNull));
    }
  });

  test('thirty characters is allowed, thirty-one is not', () {
    expect(normaliseInstagramHandle('a' * 30), 'a' * 30);
    expect(normaliseInstagramHandle('a' * 31), isNull);
  });
}
