//The full profile behind a swipe card.
//
//YOU LEAVE THIS PAGE BY DECIDING. The three buttons are pinned to the bottom
//of the screen, so reading someone's profile ends the way the deck does -
//pass, super like or like. Backing out without choosing is still possible, but
//it is the back arrow, not the obvious path.
//
//THE PHOTO RUNS TO THE TOP OF THE SCREEN, behind a transparent app bar: the
//back arrow and the report menu float over it. That is why the Scaffold
//extends behind its own app bar instead of starting below it.
//
//Everything under the photo is ProfileDetailsBody - the same widget the user's
//own preview draws, so what they arranged is what a stranger reads.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/pages/profile_pages/view_profile/profile_details_body.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/photo_card.dart';

//what the page pops with, so the deck knows what to do next
enum ProfileDecision { pass, superLike, like }

//how much of the screen the photo takes, top edge included
const double _kPhotoFraction = 0.55;

class ProfileDetailPage extends StatefulWidget {
  final int userId;
  //shown immediately, before the full profile arrives: the deck already has
  //the name and the photos, so the page never opens empty
  final PublicProfile preview;

  const ProfileDetailPage({
    super.key,
    required this.userId,
    required this.preview,
  });

  @override
  State<ProfileDetailPage> createState() => _ProfileDetailPageState();
}

class _ProfileDetailPageState extends State<ProfileDetailPage> {
  late PublicProfile _profile = widget.preview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final full = await ApiService.getUserProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = full;
        _loading = false;
      });
    } catch (_) {
      //the preview stays on screen: a name and photos beat an error page, and
      //the buttons below still work
      if (mounted) setState(() => _loading = false);
    }
  }

  void _decide(ProfileDecision decision) =>
      Navigator.pop(context, decision);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoHeight = MediaQuery.sizeOf(context).height * _kPhotoFraction;

    return Scaffold(
      //the photo runs under the bar and up to the very top of the screen
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        //the photo behind is dark enough for white controls, in both themes
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showReportMenu(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: photoHeight,
                  child: _HeaderPhoto(url: _profile.profilePictureUrl),
                ),
                //pulled up so the first card crops into the photo, as in the
                //user's own preview
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: ProfileDetailsBody(profile: _profile),
                ),
                //clear of the buttons pinned below
                const SizedBox(height: 120),
              ],
            ),
          ),

          //a hairline of progress while the rest of the profile loads; the
          //preview is already readable behind it
          if (_loading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),

          //the decision, pinned to the screen rather than to the scroll
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _DecisionBar(onDecide: _decide),
          ),
        ],
      ),
    );
  }

  void _showReportMenu(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(text.reportUser),
              onTap: () {
                Navigator.pop(sheetContext);
                //TODO: reporting needs a backend table and a reason list -
                //until then the menu exists but promises nothing
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(text.comingSoon)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPhoto extends StatelessWidget {
  final String? url;

  const _HeaderPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    if (url == null) return placeholder;

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url!,
          fit: BoxFit.cover,
          placeholder: (_, _) => placeholder,
          errorWidget: (_, _, _) => placeholder,
        ),
        //so the white back arrow and menu stay legible over a bright photo
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.3],
              colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}

//Pass, super like, like - the same three, in the same order, as on the card.
class _DecisionBar extends StatelessWidget {
  final ValueChanged<ProfileDecision> onDecide;

  const _DecisionBar({required this.onDecide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      decoration: BoxDecoration(
        //fades into the page rather than sitting on a hard edge
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.scaffoldBackgroundColor.withValues(alpha: 0),
            theme.scaffoldBackgroundColor,
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SwipeActionButton(
            icon: Icons.close,
            gradient: AppColors.passGradient,
            size: 58,
            onPressed: () => onDecide(ProfileDecision.pass),
          ),
          SwipeActionButton(
            icon: Icons.star,
            gradient: AppColors.superLikeGradient,
            size: 48,
            onPressed: () => onDecide(ProfileDecision.superLike),
          ),
          SwipeActionButton(
            icon: Icons.favorite,
            gradient: AppColors.likeGradient,
            size: 58,
            onPressed: () => onDecide(ProfileDecision.like),
          ),
        ],
      ),
    );
  }
}
