//Where the legal documents live.
//
//All of these must be PUBLIC URLs, not in-app text: Google Play requires a
//reachable privacy policy link for any app that collects personal data, and it
//checks the one on the store listing against the one in the app. Hosting the
//text in the app would also mean shipping an update to correct a typo in a
//legal document.
//
//ONE BASE URL AND A FUNCTION, which replaces five separate constants. The five
//were there so each document could be published on its own, and that stopped
//being the shape of the problem once the documents became a site: they share a
//stylesheet, they link to each other, and they go up together or not at all
//(see site/). Five constants also had nowhere to put the SECOND language -
//they would have had to become ten.
//
//A PROJECT SITE, SO THE PATH IS PART OF THE BASE. kawasakicode.github.io is
//already a user site and an account gets one, so the pages are served from a
//sub-path, FoitiFinder, underneath it. That name is case-sensitive in a URL.
//Published by .github/workflows/pages.yml, which uploads site/ as a Pages
//artifact.
//
//AN EMPTY STRING STILL MEANS "NOT PUBLISHED YET" - legalUrl returns '' for
//it and the Policies dialog says so rather than opening a blank browser tab.
//That path is kept because it is what a local build gets when this is pointed
//somewhere unreachable, and because it is the honest answer if the site ever
//comes down.
//
//Local testing: 'http://10.0.2.2:8000' from the Android emulator, or this
//machine's LAN address from a real device, with
//`python -m http.server 8000 --directory site` running. See site/README.md.
const String kLegalBaseUrl = 'https://kawasakicode.github.io/FoitiFinder/';

//THE GREEK PAGES ARE A SUBDIRECTORY, not a query parameter or a separate host,
//because the site is static files and that is the only thing static files can
//do. site/privacy.html and site/el/privacy.html, same filenames throughout, so
//this is a prefix and nothing else.
const String _kGreekPrefix = 'el/';

//Each document's filename, which is the ONLY thing the app needs to know about
//the site's shape. Named rather than passed as strings at the call site so a
//typo is a compile error.
enum LegalDocument {
  privacyStatement('privacy.html'),
  userTerms('terms.html'),
  userGuidelines('guidelines.html'),
  cancellationPolicy('cancellation.html'),
  recommenderSystem('recommender.html'),
  //NOT IN THE POLICIES DIALOG. The app deletes an account from its own screen,
  //so this page exists for Google Play's data deletion URL - which has to be
  //reachable by somebody who has already uninstalled the app, and therefore
  //cannot be a screen inside it.
  accountDeletion('delete-account.html');

  const LegalDocument(this.file);

  final String file;
}

/// The URL for [document] in [languageCode], or an empty string while the site
/// is unpublished.
///
/// ANY LANGUAGE THAT IS NOT GREEK GETS ENGLISH, deliberately: the app ships in
/// two languages and the site is translated into those two. A locale this app
/// does not have is already reading an English interface, and an English
/// document is the honest match for it - the alternative is a 404.
///
/// [base] exists so the test can supply one: the real base is empty until the
/// site is hosted, which would make every assertion about the shape of these
/// URLs pass for the wrong reason.
String legalUrl(LegalDocument document, String languageCode,
    {String base = kLegalBaseUrl}) {
  if (base.isEmpty) return '';
  final prefix = languageCode == 'el' ? _kGreekPrefix : '';
  return '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}'
      '/$prefix${document.file}';
}
