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
//OPENING IS A TRANSFORMATION, NOT A SLIDE. The card's photo grows and travels
//up into the header - one Hero, matched by tag - while the profile below
//slides in from the right and the controls simply appear on top. The route
//itself applies no transform, because a Hero works out where it is flying to
//from the destination's real position, and sliding the page would move that
//target out from under it. Same trick as photo_detail_page.dart.
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

//How the page is opened, kept beside the layout it depends on.
Route<ProfileDecision> profileDetailRoute({
  required int userId,
  required PublicProfile preview,
  required Object photoHeroTag,
}) {
  return PageRouteBuilder<ProfileDecision>(
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (_, _, _) => ProfileDetailPage(
      userId: userId,
      preview: preview,
      photoHeroTag: photoHeroTag,
    ),
    //no transform on the page: the Hero needs its destination to sit still.
    //The background fades so the deck does not simply vanish under it.
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.45, curve: Curves.easeOut),
      ),
      child: child,
    ),
  );
}

//how much of the screen the photo takes, top edge included
const double _kPhotoFraction = 0.55;

class ProfileDetailPage extends StatefulWidget {
  final int userId;
  //shown immediately, before the full profile arrives: the deck already has
  //the name and the photos, so the page never opens empty
  final PublicProfile preview;
  //matches the card the photo flew out of
  final Object? photoHeroTag;

  const ProfileDetailPage({
    super.key,
    required this.userId,
    required this.preview,
    this.photoHeroTag,
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

  void _decide(ProfileDecision decision) => Navigator.pop(context, decision);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoHeight = MediaQuery.sizeOf(context).height * _kPhotoFraction;

    //everything except the photo comes in from the right, on the same easing
    //the Hero flight uses, so the two read as one movement
    final Animation<double> routeAnimation =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final Animation<Offset> slideIn =
        Tween<Offset>(begin: const Offset(0.35, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: routeAnimation,
            curve: Curves.fastOutSlowIn,
            reverseCurve: Curves.fastOutSlowIn.flipped,
          ),
        );

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
                  child: _HeaderPhoto(
                    url: _profile.profilePictureUrl,
                    heroTag: widget.photoHeroTag,
                  ),
                ),
                //pulled up so the first card crops into the photo, as in the
                //user's own preview
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: SlideTransition(
                    position: slideIn,
                    child: ProfileDetailsBody(profile: _profile),
                  ),
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
            child: SlideTransition(
              position: slideIn,
              child: _DecisionBar(onDecide: _decide),
            ),
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(text.comingSoon)));
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
  final Object? heroTag;

  const _HeaderPhoto({required this.url, this.heroTag});

  //the photo AND its scrim fly together - see kPhotoTopScrim. The shuttle
  //rounds the corners off on the way up and back on the way down.
  Widget _maybeHero(Widget child) => heroTag == null
      ? child
      : Hero(
          tag: heroTag!,
          flightShuttleBuilder: photoHeroFlightShuttle,
          child: child,
        );

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

    //the scrim is INSIDE the Hero, so the back arrow and the menu keep the
    //same darkening under them the whole way up from the card, instead of it
    //vanishing for the flight and snapping back on landing
    return _maybeHero(
      Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: kPhotoTopScrim),
          ),
        ],
      ),
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
