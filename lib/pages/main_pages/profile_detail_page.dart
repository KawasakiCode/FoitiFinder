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
//up into the header - one Hero, matched by tag - and the profile under it
//settles into place once the photo has arrived. The route itself applies no
//transform, because a Hero works out where it is flying to from the
//destination's real position, and sliding the page would move that target out
//from under it. Same trick as photo_detail_page.dart.
//
//THE PROFILE WAITS FOR THE PHOTO, and that is not a stylistic choice. A hero
//flight is an OverlayEntry inserted into the Navigator's overlay
//(heroes.dart), which sits above every route - so while the photo is in the
//air NOTHING in this page can paint over it, no matter how the widgets here
//are stacked. The deck card is nearly the whole screen, so mid-flight the
//photo still covers most of it, including where the name card lands.
//Animating that card during the flight therefore showed it sliding along
//UNDERNEATH the photo and then jumping in front the instant the flight ended
//and the photo returned to this page's tree. The fix is to not show it until
//there is nothing in front of it: the body and the buttons fade and settle in
//over the tail of the route animation, by which point the photo is within a
//few pixels of its final rect. Closing runs it in reverse - the content
//clears out first, then the photo flies home - so there is no snap either
//way.
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

//what the page pops with, so the deck knows what to do next.
//superLike is never popped when the page is opened without that button - see
//showSuperLike below.
enum ProfileDecision { pass, superLike, like }

//How the page is opened, kept beside the layout it depends on.
Route<ProfileDecision> profileDetailRoute({
  required int userId,
  required PublicProfile preview,
  required Object photoHeroTag,
  bool showSuperLike = true,
}) {
  return PageRouteBuilder<ProfileDecision>(
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (_, _, _) => ProfileDetailPage(
      userId: userId,
      preview: preview,
      photoHeroTag: photoHeroTag,
      showSuperLike: showSuperLike,
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

//Where in the route animation the profile under the photo appears.
//
//0.72 of fastOutSlowIn is ~0.96 of the way through the flight, so the photo's
//bottom edge is within a handful of pixels of where it will rest. Earlier than
//this and the card is visibly behind the photo; later and it reads as a pop
//rather than a settle.
const double _kSettleStart = 0.72;

class ProfileDetailPage extends StatefulWidget {
  final int userId;
  //shown immediately, before the full profile arrives: the deck already has
  //the name and the photos, so the page never opens empty
  final PublicProfile preview;
  //matches the card the photo flew out of
  final Object? photoHeroTag;
  //FALSE ON THE LIKES PAGE. A super like is a way to get noticed by someone
  //who has not seen you yet; this person already liked you, so liking back
  //matches on its own and the star would buy nothing. Offering a button that
  //changes nothing is worse than not offering it.
  final bool showSuperLike;

  const ProfileDetailPage({
    super.key,
    required this.userId,
    required this.preview,
    this.photoHeroTag,
    this.showSuperLike = true,
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

    final Animation<double> routeAnimation =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;

    //The tail of the route animation, and only the tail: before _kSettleStart
    //the flying photo is still large enough to cover this content, so it
    //stays invisible rather than sliding about behind it. See the note at the
    //top of the file - the overlay the flight lives in is above this page.
    final Animation<double> settle = CurvedAnimation(
      parent: routeAnimation,
      curve: const Interval(_kSettleStart, 1, curve: Curves.easeOut),
      //closing: the parent runs 1 -> 0, so this reaches 0 while the photo has
      //barely started home - the content is gone before it could be covered
      reverseCurve: const Interval(_kSettleStart, 1, curve: Curves.easeIn),
    );
    //a short drift from the right, not a slide across the screen: by now the
    //photo has landed and this is the page arriving, not travelling
    final Animation<Offset> settleIn =
        Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero)
            .animate(settle);

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
                  child: FadeTransition(
                    opacity: settle,
                    child: SlideTransition(
                      position: settleIn,
                      child: ProfileDetailsBody(profile: _profile),
                    ),
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
            //on the same settle as the body: a decision button that arrives
            //before the profile it decides about is an invitation to misclick
            child: FadeTransition(
              opacity: settle,
              child: SlideTransition(
                position: settleIn,
                child: _DecisionBar(
                  onDecide: _decide,
                  showSuperLike: widget.showSuperLike,
                ),
              ),
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

//Pass, super like, like - the same order as on the card, with the star
//dropped where it means nothing (see showSuperLike).
class _DecisionBar extends StatelessWidget {
  final ValueChanged<ProfileDecision> onDecide;
  final bool showSuperLike;

  const _DecisionBar({required this.onDecide, required this.showSuperLike});

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
          if (showSuperLike)
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
