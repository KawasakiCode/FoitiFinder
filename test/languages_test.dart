//Every language must be translatable.
//
//catalogueLabel falls back to the canonical English string when a key is
//missing, which is right for MBTI codes and brand names but wrong here: a
//Greek user picking languages would silently read half the list in English.
//This fails if a language is added to the catalogue without its .arb entries.

import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/constants/languages.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/app_localizations_el.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';

void main() {
  test('every language has a Greek label', () {
    final AppLocalizations el = AppLocalizationsEl();
    for (final language in kLanguages) {
      final label = catalogueLabel(el, language);
      expect(
        label,
        isNot(language),
        reason: '"$language" has no entry in catalogue_labels.dart or the '
            'arb files, so Greek users would see it in English',
      );
    }
  });

  test('the list has no duplicates', () {
    expect(kLanguages.toSet().length, kLanguages.length);
  });
}
