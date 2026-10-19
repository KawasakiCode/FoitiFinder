//The match: the one screen where two people decide to actually meet.
//
//THIS IS THE SIDE THAT COMPLETED THE MATCH. They swiped right on someone who
//had already liked them, so the match exists the moment they get here and they
//answer for it NOW - there is no "decide later", because a match nobody has
//answered is a match the other person waits on forever. The other side's view
//(arriving from a notification, hours later) is not built yet.
//
//A MATCH IS NOT AN EXCHANGE. Mutual likes only make the row; the Instagram
//handles move when BOTH sides say yes again here. A swipe can be weeks stale,
//so this is where someone decides with current information - and the only
//"changed my mind" exit there will ever be, since a handle cannot be
//un-revealed once somebody has read it.
//
//SHARING TAKES TWO TAPS. It is a one-way door: the handle is the user's real
//identity, outside this app, and nothing can walk it back. The confirm dialog
//is the one place in the app where a second tap is worth the friction - and it
//names the handle being shared, so a typo caught here costs nothing.
//
//Declining is one tap, deliberately. It deletes the match and turns the like
//back into a pass, which is a loss but a private one - nobody is told, because
//the other side was never told a match existed in the first place.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/pages/main_pages/profile_detail_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/app_dialog.dart';
import 'package:foitifinder/widgets/photo_card.dart';
import 'package:foitifinder/widgets/profile_photo.dart';
import 'package:foitifinder/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

//the photo keeps the profile page's proportions, so arriving here from a card
//feels like the same place
const double _kMatchPhotoFraction = 0.5;

//HOW LONG THE BUTTONS STAY DEAD after the page appears. The user arrives here
//by tapping Like, so their thumb is already moving towards the bottom of the
//screen - and the share button lands roughly where that button was. Without
//this, a double tap sails straight through a one-way door.
const Duration _kButtonsArmAfter = Duration(milliseconds: 450);

//what the page is showing
enum _Stage { decide, waiting, revealed }

class MatchPage extends StatefulWidget {
  final int matchId;
  final int otherUserId;
  final String otherName;
  final int? otherAge;
  final String? otherPhotoUrl;
  //TRUE FOR THE OTHER SIDE OF THE MATCH. They did not just swipe - they liked
  //this person a while ago, somebody else completed the match, and a
  //notification brought them here. Two things change: they are allowed to
  //leave without answering (nothing is committed either way, and the match
  //expires on its own), and the page says who is waiting rather than
  //announcing a match they already know about.
  final bool fromNotification;
  //The exchange is already done and this is the handle being collected. The
  //page asks the server for it on open - confirm is idempotent, so a second
  //yes from the same person changes nothing and answers with the handle.
  final bool openRevealed;
  //Whether the other side has already said yes. False when this is your own
  //match waiting on you - the one you completed by swiping - so the page does
  //not announce an answer nobody has given.
  final bool theyConfirmed;

  const MatchPage({
    super.key,
    required this.matchId,
    required this.otherUserId,
    required this.otherName,
    this.otherAge,
    this.otherPhotoUrl,
    this.fromNotification = false,
    this.openRevealed = false,
    this.theyConfirmed = false,
  });

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  _Stage _stage = _Stage.decide;
  bool _busy = false;
  bool _armed = false;
  //set when the exchange completed - only possible for the side that confirms
  //second, which this side is not, until the other half of the flow exists
  String? _theirHandle;

  @override
  void initState() {
    super.initState();
    Future.delayed(_kButtonsArmAfter, () {
      if (mounted) setState(() => _armed = true);
    });
    if (widget.openRevealed) _collectRevealed();
  }

  //Opened from a "you're connected" notification: ask for the handle rather
  //than asking the user to confirm something they already confirmed.
  Future<void> _collectRevealed() async {
    setState(() => _busy = true);
    try {
      final result = await ApiService.confirmMatch(widget.matchId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        //still not revealed means the other side has since declined, or one
        //of the handles is missing - the waiting copy is the honest answer
        _stage = result.revealed ? _Stage.revealed : _Stage.waiting;
        _theirHandle = result.instagramHandle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.errorOccured)));
    }
  }

  //The user's own handle, to name in the confirm dialog. Already required and
  //already validated by the time anyone can swipe (SetupWrapper), so the
  //fallback is only for a cache written before the handle existed.
  String get _myHandle =>
      context.read<ProfileProvider>().currentUser?.instagramHandle ?? '';

  Future<void> _share() async {
    //STEP TWO. The dialog says the handle out loud rather than asking an
    //abstract "are you sure" - the thing worth checking is what is about to
    //be shared, not whether the user meant to tap.
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.matchConfirmTitle),
        content: Text(text.matchConfirmBody(widget.otherName, _myHandle)),
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
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ApiService.confirmMatch(widget.matchId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        //revealed can only come back true if the other side had already said
        //yes. It cannot happen on this side today - their confirm needs a
        //match that only this swipe just created - but the server answers it
        //either way, and dropping it would be a dead end the day it can.
        _stage = result.revealed ? _Stage.revealed : _Stage.waiting;
        _theirHandle = result.instagramHandle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.errorOccured)));
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await ApiService.declineMatch(widget.matchId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      //STAYS ON THE PAGE on failure. Popping would leave a match the user
      //thinks they refused, and the other side would eventually be shown it.
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.errorOccured)));
    }
  }

  Future<void> _copyHandle() async {
    final handle = _theirHandle;
    if (handle == null) return;
    await Clipboard.setData(ClipboardData(text: handle));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.matchCopied)));
  }

  Future<void> _openInstagram() async {
    final handle = _theirHandle;
    if (handle == null) return;
    //the app's own scheme first, the web profile if it is not installed
    for (final uri in [
      Uri.parse('instagram://user?username=$handle'),
      Uri.parse('https://instagram.com/$handle'),
    ]) {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      profileDetailRoute(
        userId: widget.otherUserId,
        photoHeroTag: 'match-profile-${widget.otherUserId}',
        //READ ONLY. The decision being made is on this page, and a second set
        //of like/pass buttons on the profile would be a different answer to
        //the same question.
        decisions: false,
        preview: PublicProfile(
          id: widget.otherUserId,
          name: widget.otherName,
          age: widget.otherAge,
          photos: [
            if (widget.otherPhotoUrl != null)
              ProfilePhoto(url: widget.otherPhotoUrl!),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoHeight =
        MediaQuery.sizeOf(context).height * _kMatchPhotoFraction;

    //NO WAY OUT BUT AN ANSWER, for the side that just swiped. The match row
    //was created by that swipe, so backing out would leave it unanswered and
    //the other person waiting on somebody who has moved on.
    //
    //The side that arrives from a notification is the opposite case: the match
    //has been sitting there anyway, they were interrupted to look at it, and
    //trapping them in a page they did not choose to open is not the way to ask
    //for an Instagram handle. Leaving means the match keeps waiting, and it
    //expires on its own.
    return PopScope(
      canPop: widget.fromNotification || _stage != _Stage.decide,
      child: Scaffold(
        body: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: photoHeight,
              child: _MatchPhoto(url: widget.otherPhotoUrl),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: switch (_stage) {
                  _Stage.decide => _buildDecide(theme),
                  _Stage.waiting => _buildWaiting(theme),
                  _Stage.revealed => _buildRevealed(theme),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecide(ThemeData theme) {
    final name = widget.otherName;
    final who = widget.otherAge == null ? name : '$name, ${widget.otherAge}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          //arriving from a notification about a match THEY have answered,
          //the news is their yes; otherwise it is still the match itself
          widget.fromNotification && widget.theyConfirmed
              ? text.matchTheirTurn(name)
              : text.matchTitle,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(who, style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Text(
          text.matchHowItWorks(name),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        //for the side that swiped weeks ago and does not remember this person.
        //Harmless here, essential once the other half of the flow exists.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _openProfile,
            child: Text(text.matchViewProfile),
          ),
        ),
        const Spacer(),
        PrimaryButton(
          label: text.matchShare,
          onPressed: (_busy || !_armed) ? null : _share,
        ),
        TextButton(
          onPressed: (_busy || !_armed) ? null : _decline,
          child: Text(
            text.matchDecline,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildWaiting(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text.matchWaitingTitle(widget.otherName),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          text.matchWaitingBody(widget.otherName),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        PrimaryButton(
          label: text.matchDone,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildRevealed(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text.matchRevealedTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        //big, because people screenshot this
        SelectableText(
          '@${_theirHandle ?? ''}',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyHandle,
                icon: const Icon(Icons.copy_outlined),
                label: Text(text.matchCopy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openInstagram,
                icon: const Icon(Icons.open_in_new),
                label: Text(text.matchOpenInstagram),
              ),
            ),
          ],
        ),
        const Spacer(),
        PrimaryButton(
          label: text.matchDone,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _MatchPhoto extends StatelessWidget {
  final String? url;

  const _MatchPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null) return const PhotoMissingBox();

    return Stack(
      fit: StackFit.expand,
      children: [
        //the same key the card and the profile header use, so the photo is
        //already decoded by the time a match opens
        PersonPhoto(url: url),
        const DecoratedBox(decoration: BoxDecoration(gradient: kPhotoTopScrim)),
      ],
    );
  }
}
