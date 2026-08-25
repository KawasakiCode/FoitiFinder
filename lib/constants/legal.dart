//Where the legal documents live.
//
//All of these must be PUBLIC URLs, not in-app text: Google Play requires a
//reachable privacy policy link for any app that collects personal data, and it
//checks the one on the store listing against the one in the app. Hosting the
//text in the app would also mean shipping an update to correct a typo in a
//legal document.
//
//Empty until each document is written and hosted. The Policies dialog treats an
//empty string as "not published yet" and says so rather than opening a blank
//browser tab, so these can be filled in one at a time.
const String kPrivacyStatementUrl = '';
const String kUserTermsUrl = '';
const String kUserGuidelinesUrl = '';
const String kCancellationPolicyUrl = '';

//Not a legal document but it sits with them: the plain-language explanation of
//how the feed is put together.
//
//NOT currently required of us. DSA Article 27 obliges online platforms to set
//out their recommender system's main parameters in plain language, but Article
//19 exempts micro and small enterprises, which is what we are. Worth publishing
//anyway - the big apps do it, users ask, and it stops being optional the moment
//we outgrow the exemption.
const String kRecommenderSystemUrl = '';
