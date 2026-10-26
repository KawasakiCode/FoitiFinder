//The match's action, pinned under a profile.
//
//WHY IT IS A BAR AND NOT A PAGE. A match reached from the matches page is a
//person you are deciding about, and the app already has one way to read a
//person: the full scrollable profile the deck and the matches grid both open.
//Putting the action under it means there is no second place that shows
//somebody, and you can read the bio before handing over an Instagram handle -
//which is the whole decision.
//
//MatchPage stays as it is, for the moment a match is MADE: that one is a
//celebration with its own layout, reached by swiping right on someone who had
//already liked you. This bar is for coming back to it later.
//
//THREE STATES, FROM THE SERVER, NOT GUESSED:
//    waiting on me    -> share, or decline
//    waiting on them  -> told so, and nothing to press
//    revealed         -> their handle, to copy or open
//
//NO ARMING DELAY HERE, unlike MatchPage. That timer exists because you arrive
//there by tapping like, with your thumb already travelling towards the bottom
//of the screen. You arrive here by tapping a tile and scrolling a profile, so
//there is no momentum to protect against.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:foitifinder/models/matches_model.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/app_dialog.dart';
import 'package:foitifinder/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

//STEP TWO OF SHARING, and the reason it is here rather than inlined twice:
//the dialog names the handle out loud instead of asking an abstract "are you
//sure". The thing worth checking at this moment is WHAT is about to be
//shared - a typo caught here costs nothing, and afterwards nobody can take it
//back. MatchPage asks exactly the same question.
Future<bool> confirmShareDialog(
  BuildContext context, {
  required String otherName,
  required String myHandle,
}) async {
  final text = AppLocalizations.of(context)!;
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(text.matchConfirmTitle),
      content: Text(text.matchConfirmBody(otherName, myHandle)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(text.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(text.matchConfirmAction),
        ),
      ],
    ),
  );
  return confirmed == true;
}

//Open their Instagram: the app if it is installed, the web profile if not.
Future<void> openInstagram(String handle) async {
  for (final uri in [
    Uri.parse('instagram://user?username=$handle'),
    Uri.parse('https://instagram.com/$handle'),
  ]) {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  }
}

class MatchActionBar extends StatefulWidget {
  final MatchModel match;
  //called after the match changes, so the list behind can reload
  final VoidCallback? onChanged;

  const MatchActionBar({super.key, required this.match, this.onChanged});

  @override
  State<MatchActionBar> createState() => _MatchActionBarState();
}

class _MatchActionBarState extends State<MatchActionBar> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  late bool _iConfirmed = widget.match.iConfirmed;
  late bool _revealed = widget.match.revealed;
  String? _theirHandle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    //ALREADY EARNED, SO FETCH IT. confirm is idempotent, which makes a second
    //call a read - and it is the only endpoint that hands a handle over, so
    //this is how the page gets one without a second route that can leak it.
    if (_revealed) _collectHandle();
  }

  Future<void> _collectHandle() async {
    setState(() => _busy = true);
    try {
      final result = await ApiService.confirmMatch(widget.match.matchId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _revealed = result.revealed;
        _theirHandle = result.instagramHandle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _complain();
    }
  }

  void _complain() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.errorOccured)));
  }

  String get _myHandle =>
      context.read<ProfileProvider>().currentUser?.instagramHandle ?? '';

  Future<void> _share() async {
    final confirmed = await confirmShareDialog(
      context,
      otherName: widget.match.otherUserName,
      myHandle: _myHandle,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ApiService.confirmMatch(widget.match.matchId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _iConfirmed = true;
        _revealed = result.revealed;
        _theirHandle = result.instagramHandle;
      });
      widget.onChanged?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _complain();
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await ApiService.declineMatch(widget.match.matchId);
      if (!mounted) return;
      widget.onChanged?.call();
      //the match is gone, so the profile behind it has nothing left to act on
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      //STAYS PUT on failure. Popping would leave the user believing they had
      //refused a match that is still standing, and the other side would
      //eventually be shown it.
      setState(() => _busy = false);
      _complain();
    }
  }

  Future<void> _copy() async {
    final handle = _theirHandle;
    if (handle == null) return;
    await Clipboard.setData(ClipboardData(text: handle));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.matchCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: SafeArea(top: false, child: _content(theme)),
    );
  }

  Widget _content(ThemeData theme) {
    if (_revealed) return _revealedContent(theme);
    //BEFORE THE TURN CHECKS. An expired match is still somebody's turn by the
    //flags, and offering the share button would be offering a press the
    //server now answers 409 to.
    if (widget.match.expired) return _expiredContent(theme);
    if (_iConfirmed) return _waitingContent(theme);
    return _decideContent();
  }

  //IT RAN OUT. The only state here with nothing to press and nothing coming:
  //this is the notice, and the match leaves the list on its own in a day or
  //two. Says WHO did not answer, because "expired" on its own reads like the
  //app lost something.
  Widget _expiredContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text.matchExpiredTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          //whoever owed the answer is who it names: if I had confirmed, they
          //went quiet; if I had not, it lapsed on me
          _iConfirmed
              ? text.matchExpiredTheirs(widget.match.otherUserName)
              : text.matchExpiredMine,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  //BOTH SAID YES. The handle, and the two things anyone does with one.
  Widget _revealedContent(ThemeData theme) {
    final handle = _theirHandle;
    if (_busy && handle == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text.matchRevealedTitle,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          '@${handle ?? ''}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: handle == null ? null : _copy,
                icon: const Icon(Icons.copy, size: 18),
                label: Text(text.matchCopy),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: handle == null ? null : () => openInstagram(handle),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(text.matchOpenInstagram),
              ),
            ),
          ],
        ),
      ],
    );
  }

  //YOU HAVE ANSWERED, THEY HAVE NOT. Nothing to press: the only thing that
  //can move this on is them, and a button that cannot help is worse than none.
  Widget _waitingContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text.matchWaitingTitle(widget.match.otherUserName),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          text.matchWaitingBody(widget.match.otherUserName),
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        //THE DEADLINE, NAMED. 'Matches expire after three days' belongs in a
        //help screen nobody opens; the day it actually runs out is the only
        //version of this anybody reads. Absent rather than guessed if the
        //server did not send one.
        if (_deadline != null) ...[
          const SizedBox(height: 8),
          Text(
            text.matchExpiresOn(widget.match.otherUserName, _deadline!),
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  //The deadline as a weekday, or null when there is nothing to count down to.
  //
  //A WEEKDAY, NOT A DATE. Three days out is always inside the next week, so
  //'Thursday' is both shorter and easier to place than a numeric date - and
  //it needs no format that differs per locale beyond the name itself.
  String? get _deadline {
    final expiresAt = widget.match.expiresAt;
    if (expiresAt == null) return null;
    return DateFormat.EEEE(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(expiresAt);
  }

  Widget _decideContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          label: text.matchShare,
          onPressed: _busy ? null : _share,
          isLoading: _busy,
        ),
        TextButton(
          onPressed: _busy ? null : _decline,
          child: Text(
            text.matchDecline,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
