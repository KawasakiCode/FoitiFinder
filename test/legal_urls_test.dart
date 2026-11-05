//Which legal document the app opens, and in which language.
//
//WHY THIS IS WORTH TESTING AT ALL. It is string concatenation - but it is
//string concatenation that decides whether a Greek student reading a Greek
//interface is handed a Greek privacy policy or an English one, and whether
//Google Play's data deletion URL resolves to a page or to a 404. Both of those
//fail silently: a wrong URL opens a browser showing "not found", which looks
//like a network problem rather than a bug here.
//
//THE BASE IS INJECTED. The real one is empty until the site is hosted, so
//every assertion about the shape of these URLs would otherwise pass by
//agreeing that an empty string is an empty string.

import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/constants/legal.dart';

const String kBase = 'https://example.org';

void main() {
  group('the language decides the directory', () {
    test('English is the site root', () {
      expect(
        legalUrl(LegalDocument.privacyStatement, 'en', base: kBase),
        'https://example.org/privacy.html',
      );
    });

    test('Greek is the el subdirectory', () {
      expect(
        legalUrl(LegalDocument.privacyStatement, 'el', base: kBase),
        'https://example.org/el/privacy.html',
      );
    });

    test('and anything else falls back to English', () {
      //A LOCALE THE APP DOES NOT HAVE is already showing an English interface,
      //so an English document matches it. The alternative is a 404, which is
      //what a /de/ directory that was never written would be.
      expect(
        legalUrl(LegalDocument.userTerms, 'de', base: kBase),
        'https://example.org/terms.html',
      );
    });
  });

  group('every document has a page', () {
    test('and the filenames are the ones in site/', () {
      //THESE MUST MATCH THE FILES ON DISK. If a page is renamed in site/ and
      //not here, the app opens a 404 - and nothing else in either the app or
      //the site would notice, because the two halves never meet until a user
      //taps a row in the Policies dialog.
      expect(
        {
          for (final document in LegalDocument.values) document: document.file
        },
        {
          LegalDocument.privacyStatement: 'privacy.html',
          LegalDocument.userTerms: 'terms.html',
          LegalDocument.userGuidelines: 'guidelines.html',
          LegalDocument.cancellationPolicy: 'cancellation.html',
          LegalDocument.recommenderSystem: 'recommender.html',
          LegalDocument.accountDeletion: 'delete-account.html',
        },
      );
    });

    test('in both languages, with no duplicates', () {
      final urls = {
        for (final language in ['en', 'el'])
          for (final document in LegalDocument.values)
            legalUrl(document, language, base: kBase),
      };

      expect(urls.length, LegalDocument.values.length * 2,
          reason: 'two documents resolved to the same URL');
    });
  });

  group('an unpublished site', () {
    test('resolves to nothing rather than to a broken URL', () {
      //THE SHIPPING STATE. The Policies dialog reads an empty string as "not
      //published yet" and says so; a half-formed URL like '/privacy.html'
      //would instead open a browser on a page that cannot exist.
      for (final document in LegalDocument.values) {
        for (final language in ['en', 'el']) {
          expect(legalUrl(document, language, base: ''), isEmpty);
        }
      }
    });

    test('which is what the app is built with today', () {
      //the default argument, not an injected one: this is the assertion that
      //fails on the day kLegalBaseUrl is filled in, as a reminder that the
      //store listing's privacy policy link has to match it
      expect(legalUrl(LegalDocument.privacyStatement, 'en'), isEmpty);
    });
  });

  test('a trailing slash on the base does not double up', () {
    //whoever fills kLegalBaseUrl in will paste it out of a browser
    expect(
      legalUrl(LegalDocument.userGuidelines, 'el', base: 'https://example.org/'),
      'https://example.org/el/guidelines.html',
    );
  });
}
