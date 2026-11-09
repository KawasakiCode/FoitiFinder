//Opening one of the published legal documents in a browser.
//
//WHY THIS IS SHARED RATHER THAN WRITTEN PER SCREEN. Three places open these
//documents - the Policies dialog on the profile page, the consent line under
//the sign up form, and the delete account page - and two of the three shipped
//pointing at a search engine's home page, a placeholder left from before the
//site existed. Nothing caught it: the destination is a string, a browser
//opening the wrong page looks exactly like a link that works, and each screen
//had its own copy of the launch so fixing one fixed neither of the others.
//Going through here means the next screen that needs a policy link cannot
//invent a destination of its own - it names a LegalDocument and the URL is
//derived.
//
//EXTERNAL BROWSER ON PURPOSE. Google Play requires a publicly reachable
//privacy policy and checks the listing's URL against the app's, and holding
//the text in the app would mean shipping an update to correct a typo in a
//legal document. See constants/legal.dart for where the pages live.

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/legal.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [document] in the language the interface is currently in.
Future<void> openLegalDocument(
  BuildContext context,
  LegalDocument document,
) async {
  //THE DOCUMENT FOLLOWS THE INTERFACE. Read from the active locale rather than
  //from the settings provider, so it follows whatever Flutter actually
  //resolved - a Greek screen cannot hand out an English policy.
  final language = Localizations.localeOf(context).languageCode;
  await openLegalUrl(context, legalUrl(document, language));
}

/// Opens an already-resolved legal [url], or explains why it cannot.
///
/// Takes a string rather than a [LegalDocument] because the Policies dialog
/// resolves its URLs while it builds its rows and pops the chosen one.
Future<void> openLegalUrl(BuildContext context, String url) async {
  final text = AppLocalizations.of(context)!;

  //NOT PUBLISHED YET -> say so instead of opening a blank tab. legalUrl
  //returns an empty string when kLegalBaseUrl is empty, which is what a build
  //pointed at an unhosted site gets.
  if (url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.comingSoon)),
    );
    return;
  }

  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );

  //NO canLaunchUrl CHECK. On Android 11 and up it answers for the intent
  //query, not for the launch, and returns false for a perfectly openable
  //https URL unless the manifest declares a matching <queries> entry. The
  //launch's own result is the honest answer.
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text.errorOccured),
        backgroundColor: Colors.red,
      ),
    );
  }
}
