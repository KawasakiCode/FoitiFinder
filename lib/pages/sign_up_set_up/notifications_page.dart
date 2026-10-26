//The last thing setup asks for: permission to tell you about a match.
//
//WHY IT IS ASKED AT ALL, RATHER THAN WHEN IT MATTERS. The usual rule for a
//runtime permission is to ask at the moment its value is obvious, and for
//'they said yes back' that moment exists - you have just shared a handle and
//are about to wait. But the other push, 'somebody matched with you and is
//waiting on your answer', IS how you find out a match happened. Asking after
//the fact is too late, because the fact is what the asking was for. So it
//has to be asked before there is anything to be notified about.
//
//WHY HERE AND NOT ON THE HANDLE PAGE. That page is where the exchange is
//explained - no chat, a match swaps handles - so it is tempting to ask right
//after it. It is also FIRST, deliberately, because the handle is the question
//most likely to make somebody close the app, and stacking a permission onto
//that is the worst adjacency in the flow: two permission-shaped questions
//back to back, twenty seconds in, before the app has done anything for them.
//
//The understanding from that page keeps. By the time setup ends they know
//what a match is worth, they have put in a handle, photos and preferences,
//and the next thing they will see is the deck. That is when to ask.
//
//IT ASKS BEFORE THE OS DOES, which is the whole point of the screen. Android
//permanently denies after two dismissals and the only recovery is the system
//settings screen, so a dismissed OS prompt is one of two chances gone. A
//dismissed screen like this one costs nothing and can be followed by the real
//prompt later. 'Not now' therefore never triggers the OS dialog at all.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/primary_button.dart';
import 'package:provider/provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _busy = false;

  AppLocalizations get text => AppLocalizations.of(context)!;

  //EITHER ANSWER ENDS THE QUESTION. The flag is what SetupWrapper reads to
  //stop showing this screen, so it is written on both paths - a 'Not now'
  //that got asked again next launch would be the same nagging the pre-prompt
  //exists to avoid.
  Future<void> _answer({required bool allow}) async {
    if (_busy) return;
    setState(() => _busy = true);

    final settings = context.read<SettingsProvider>();
    if (allow) {
      //the real OS dialog, reached only from the positive button
      await settings.toggleMatchNotifications(true);
    }
    //NO else BRANCH WRITING false. The stored setting already defaults off,
    //and turning it explicitly off here would be recorded as a preference
    //the user never stated - they declined a prompt, which is not the same
    //as asking for silence forever.
    await settings.markNotificationsAsked();

    //NORMALLY UNREACHABLE, AND HERE ON PURPOSE. Setting the flag notifies
    //SetupWrapper, which rebuilds this screen away into the deck - so this
    //line usually runs on a widget that is already gone. If that rebuild
    //ever fails to happen, the alternative is a spinner with no way out of
    //it, and a button that came back is a far better failure.
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_active_outlined,
                  size: 88, color: AppColors.primary),
              const SizedBox(height: 28),
              Text(
                text.askNotificationsTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              //SAYS WHAT THE TWO PUSHES ARE, because "allow notifications" is
              //a question nobody can answer. These are the only two the app
              //sends, and both are about somebody waiting on the user.
              Text(
                text.askNotificationsBody,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: text.askNotificationsAllow,
                onPressed: _busy ? null : () => _answer(allow: true),
                isLoading: _busy,
              ),
              //NOT A BUTTON THAT LOOKS LIKE THE OTHER ONE. Declining is a
              //real option here - it can be changed in settings afterwards,
              //and a prompt with only one way out is how people end up
              //permanently denying it at the OS instead.
              TextButton(
                onPressed: _busy ? null : () => _answer(allow: false),
                child: Text(
                  text.askNotificationsLater,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
