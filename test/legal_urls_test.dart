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
      //NO LONGER THE SHIPPING STATE - the site is up and kLegalBaseUrl points
      //at it - but still the behaviour a local build gets with the base
      //cleared, and still what should happen if the site ever comes down. The
      //Policies dialog reads an empty string as "not published yet" and says
      //so; a half-formed URL like '/privacy.html' would instead open a browser
      //on a page that cannot exist.
      for (final document in LegalDocument.values) {
        for (final language in ['en', 'el']) {
          expect(legalUrl(document, language, base: ''), isEmpty);
        }
      }
    });
  });

  group('the site this app actually points at', () {
    //THE DEFAULT ARGUMENT, not an injected one. This group replaces an
    //assertion that kLegalBaseUrl was still empty, which was a tripwire for
    //the day the site went up. It has gone up, so the tripwire is spent and
    //these take its place: the thing worth guarding now is not that the base
    //is unset but that it keeps pointing where the pages really are.
    //
    //THE STORE LISTING HAS TO MATCH. Play checks the privacy policy URL on the
    //listing against the one the app opens, so the first URL below is a value
    //that exists in two places and only one of them is in this repo.

    test('the privacy policy resolves to the published page', () {
      expect(
        legalUrl(LegalDocument.privacyStatement, 'en'),
        'https://kawasakicode.github.io/FoitiFinder/privacy.html',
      );
    });

    test('and the Greek one to its translation', () {
      expect(
        legalUrl(LegalDocument.privacyStatement, 'el'),
        'https://kawasakicode.github.io/FoitiFinder/el/privacy.html',
      );
    });

    test('the account deletion page is reachable for Play', () {
      //NOT IN THE POLICIES DIALOG and therefore not covered by any test that
      //walks the dialog. Play wants a data deletion URL that works for
      //somebody who has already uninstalled, so this one has to resolve on
      //its own.
      expect(
        legalUrl(LegalDocument.accountDeletion, 'en'),
        'https://kawasakicode.github.io/FoitiFinder/delete-account.html',
      );
    });

    test('every document resolves to something', () {
      //the guard against a base that is accidentally emptied again: without
      //this, the "unpublished site" group above would still pass and nothing
      //would notice that the app had stopped opening its own policies
      for (final document in LegalDocument.values) {
        for (final language in ['en', 'el']) {
          expect(legalUrl(document, language), isNotEmpty,
              reason: 'kLegalBaseUrl is empty or $document lost its file');
        }
      }
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
