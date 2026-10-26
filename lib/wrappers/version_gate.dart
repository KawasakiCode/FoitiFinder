//Stops a build the backend will no longer talk to.
//
//WHY THIS HAS TO EXIST BEFORE IT IS EVER USED. A build on somebody's phone
//cannot be changed, only replaced - so the CHECK has to be inside it. A
//release shipped without this one can never be told to stop, whatever the
//server says afterwards, which is why it is here while the minimum is still
//1 and it blocks nobody. See backend/app_version.py for when that is raised.
//
//ABOVE THE WHOLE APP, in MaterialApp's builder next to InternetWrapper, so it
//covers the login page too. An update wall that only appears once you have
//signed in is a wall with a door next to it - and a build old enough to be
//refused may be old enough to get signing in wrong.
//
//IT DOES NOT BLOCK STARTUP. The backend cold-starts on its free plan and can
//take the better part of a minute to answer the first request of the day, so
//the app comes up normally and the wall arrives when the answer does. Waiting
//for it would turn every first launch into a long white screen, which is the
//exact failure this is supposed to be cheaper than.
//
//AND IT FAILS OPEN. No answer, a bad answer, no network - the app runs. The
//only thing worse than an old build still working is a current one that
//refuses to start because a request timed out.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/primary_button.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

//WHERE THE UPDATE COMES FROM. The package name rather than a store id,
//because Play resolves it and the same URL opens the installed Play app or
//the web page if there is none.
//
//NOT YET THE REAL ONE: the app still ships as com.example.foitifinder, which
//Play refuses to accept at upload. This link is correct the day that changes,
//and wrong in exactly the same way the package name is until then.
const String kStoreUrl =
    'https://play.google.com/store/apps/details?id=com.example.foitifinder';

/// Whether a build of [mine] must stop talking to a backend asking for
/// [minimum]. Null for either means "not known", which always lets the app run.
///
/// A FUNCTION RATHER THAN THREE LINES INSIDE _check, so the rule can be tested
/// without a platform or a network - and tested as the rule itself rather than
/// as a copy of it written in the test file, which is free to drift from this
/// one the moment either changes.
bool buildIsTooOld({required int? minimum, required int? mine}) {
  //THE SERVER SAID NOTHING USABLE: no network, a cold start that timed out, a
  //500, or a reply that is not a number. None of those are evidence that this
  //build is old.
  if (minimum == null) return false;
  //AND A BUILD THAT CANNOT SAY WHICH BUILD IT IS is not evidence either.
  //buildNumber is a string and has come back empty on some Android builds.
  if (mine == null) return false;
  //'minimum SUPPORTED', so the minimum itself passes. An off-by-one here
  //locks out the exact build everybody was just told to install.
  return mine < minimum;
}

class VersionGate extends StatefulWidget {
  final Widget child;

  const VersionGate({super.key, required this.child});

  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> {
  bool _tooOld = false;

  @override
  void initState() {
    super.initState();
    //not awaited: see the note above about not blocking startup
    _check();
  }

  Future<void> _check() async {
    final minimum = await ApiService.minimumBuild();
    //nothing usable came back, so there is no reason to read our own version
    if (minimum == null) return;

    final info = await PackageInfo.fromPlatform();
    //AN INTEGER, NOT A VERSION NAME. buildNumber is Android's versionCode and
    //only ever goes up, so the comparison has no edge cases - where comparing
    //'1.10.0' against '1.9.0' as strings quietly gets it backwards.
    final mine = int.tryParse(info.buildNumber);

    if (!buildIsTooOld(minimum: minimum, mine: mine)) return;
    if (mounted) setState(() => _tooOld = true);
  }

  @override
  Widget build(BuildContext context) {
    //REPLACED, NOT COVERED. A dialog over a running app can be dismissed, and
    //everything behind it still works; the point here is that nothing behind
    //it should.
    if (_tooOld) return const UpdateWall();
    return widget.child;
  }
}

/// The screen a build that is too old gets instead of the app.
///
/// PUBLIC so a test can pump it directly. The gate only reaches it after two
/// async calls that a widget test has no platform to answer, so a wall that
/// was private would be the one part of this feature nothing ever looked at.
class UpdateWall extends StatelessWidget {
  const UpdateWall({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update,
                    size: 88, color: AppColors.primary),
                const SizedBox(height: 24),
                Text(
                  text.updateRequiredTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  text.updateRequiredBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 28),
                //NO 'later' AND NO WAY BACK. There is nothing behind this
                //screen that would work, so an escape from it would only lead
                //to an app answering errors to everything.
                PrimaryButton(
                  label: text.updateRequiredAction,
                  onPressed: () => launchUrl(
                    Uri.parse(kStoreUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
