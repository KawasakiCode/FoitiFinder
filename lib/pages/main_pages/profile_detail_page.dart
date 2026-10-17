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
//OPENING IS A TRANSFORMATION, NOT A SLIDE. The card comes apart and becomes
//this page: the photo grows and travels up into the header, the card's three
//buttons travel down into the bar at the bottom (a second Hero, so they are
//literally the same buttons), and the profile between them slides in from the
//right once the photo has arrived. The route itself applies no
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
//and the photo returned to this page's tree.
//
//So the two things are SEQUENCED, not overlapped. Nothing in the page is
//painted until the flight finishes (_landed); then the profile slides in from
//the right on its own controller, at its own duration, which is why it runs
//at the same speed as a normal page push rather than being squeezed into
//whatever is left of the route animation. Closing runs it backwards, and
//faster: the content clears out while the photo is still on its way home.
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
  Object? actionsHeroTag,
  bool showSuperLike = true,
  bool decisions = true,
}) {
  return PageRouteBuilder<ProfileDecision>(
    //THIS IS THE FLIGHT'S DURATION TOO. A hero flight runs on the route's
    //animation, so these two numbers are what makes the photo and the buttons
    //travel at the speed they do.
    transitionDuration: const Duration(milliseconds: 680),
    reverseTransitionDuration: const Duration(milliseconds: 520),
    pageBuilder: (_, _, _) => ProfileDetailPage(
      userId: userId,
      preview: preview,
      photoHeroTag: photoHeroTag,
      actionsHeroTag: actionsHeroTag,
      showSuperLike: showSuperLike,
      decisions: decisions,
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

//How long the profile takes to slide in once the photo has landed, and how
//quickly it leaves. The forward number is the route's own transition duration:
//this is a page arriving, and it should move like one.
const Duration _kBodySlideIn = Duration(milliseconds: 620);
const Duration _kBodySlideOut = Duration(milliseconds: 300);

class ProfileDetailPage extends StatefulWidget {
  final int userId;
  //shown immediately, before the full profile arrives: the deck already has
  //the name and the photos, so the page never opens empty
  final PublicProfile preview;
  //matches the card the photo flew out of
  final Object? photoHeroTag;
  //matches the card's button row, when it was opened from something that has
  //one. Null from the likes grid: a tile has no buttons to fly from, so the
  //bar arrives with the rest of the page instead.
  final Object? actionsHeroTag;
  //FALSE ON THE LIKES PAGE. A super like is a way to get noticed by someone
  //who has not seen you yet; this person already liked you, so liking back
  //matches on its own and the star would buy nothing. Offering a button that
  //changes nothing is worse than not offering it.
  final bool showSuperLike;
  //FALSE WHEN THE DECISION IS SOMEBODY ELSE'S PAGE. The match page asks one
  //question and asks it there; a second set of like/pass buttons under the
  //profile would be a different answer to the same thing. The page is then
  //purely something to read - which is the point of opening it from a match
  //you swiped on weeks ago and have forgotten.
  final bool decisions;

  const ProfileDetailPage({
    super.key,
    required this.userId,
    required this.preview,
    this.photoHeroTag,
    this.actionsHeroTag,
    this.showSuperLike = true,
    this.decisions = true,
  });

  @override
  State<ProfileDetailPage> createState() => _ProfileDetailPageState();
}

class _ProfileDetailPageState extends State<ProfileDetailPage>
    with SingleTickerProviderStateMixin {
  late PublicProfile _profile = widget.preview;
  bool _loading = true;

  //false until the hero flight has finished. While it is false NOTHING in this
  //page is painted - see the note at the top of the file.
  bool _landed = false;
  late final AnimationController _body = AnimationController(
    vsync: this,
    duration: _kBodySlideIn,
    reverseDuration: _kBodySlideOut,
  );
  late final Animation<Offset> _bodySlide =
      Tween<Offset>(begin: const Offset(0.35, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _body,
          curve: Curves.fastOutSlowIn,
          reverseCurve: Curves.fastOutSlowIn.flipped,
        ),
      );
  //the route's own animation, watched for the end of the flight
  Animation<double>? _route;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context)?.animation;
    if (route == _route) return;
    _route?.removeStatusListener(_onRouteStatus);
    _route = route;
    //pushed with no transition at all (or already finished): there is no
    //flight to wait for, so the page is simply here
    if (route == null || route.isCompleted) {
      _land();
    } else {
      route.addStatusListener(_onRouteStatus);
    }
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_onRouteStatus);
    _body.dispose();
    super.dispose();
  }

  void _onRouteStatus(AnimationStatus status) {
    //completed = the photo (and the buttons) have arrived
    if (status.isCompleted) {
      _land();
    } else if (status == AnimationStatus.reverse) {
      //closing: hide the real buttons again so the only ones on screen are
      //the pair flying back to the card, and send the profile out to the right
      if (_landed) setState(() => _landed = false);
      _body.reverse();
    }
  }

  void _land() {
    if (!_landed && mounted) setState(() => _landed = true);
    _body.forward();
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
                  //OPACITY, NOT A FADE, and not Visibility: it must keep its
                  //size so the scroll view does not jump when it appears, and
                  //it must not be painted at all while the photo is in the air
                  child: Opacity(
                    opacity: _landed ? 1 : 0,
                    child: SlideTransition(
                      position: _bodySlide,
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
          //KEYED, and that is a bug fix, not tidiness. A Stack's children are
          //matched by position when nothing is keyed, so the frame this one
          //disappears on handed the bar's widget to the progress bar's
          //element - both are Positioned. The bar's subtree was rebuilt from
          //scratch mid-flight, which gave its Hero a fresh state that knew
          //nothing about the flight in progress, so the real buttons appeared
          //at the bottom while their copy was still travelling. The profile
          //loads in a few milliseconds against a local backend, which is why
          //it happened every single time there.
          if (_loading)
            Positioned(
              key: const ValueKey('loading-hairline'),
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
          if (widget.decisions)
            Positioned(
            key: const ValueKey('decision-bar'),
            left: 0,
            right: 0,
            bottom: 0,
            //INVISIBLE AND UNTAPPABLE UNTIL THE FLIGHT LANDS. The copy of
            //these buttons travelling down from the card is the only pair on
            //screen until then; these take over the instant it arrives.
            //Opacity is deliberate - a SlideTransition would move them, and a
            //Hero measures its destination where it currently sits, so the
            //flight would aim at the wrong place.
            child: IgnorePointer(
              ignoring: !_landed,
              child: Opacity(
                opacity: _landed ? 1 : 0,
                child: widget.actionsHeroTag != null
                    //flown in from the card: already where it belongs
                    ? _DecisionBar(
                        onDecide: _decide,
                        showSuperLike: widget.showSuperLike,
                        heroTag: widget.actionsHeroTag,
                      )
                    //nothing to fly from (the likes grid), so it arrives with
                    //the profile instead
                    : SlideTransition(
                        position: _bodySlide,
                        child: _DecisionBar(
                          onDecide: _decide,
                          showSuperLike: widget.showSuperLike,
                        ),
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

  //NO flightShuttleBuilder HERE, deliberately. Flutter prefers the
  //destination hero's shuttle, so one declared on this page would describe
  //every flight that lands here - including the one out of the likes grid,
  //which has no pills and no card darkening to fade. Leaving it null falls
  //through to whichever source the photo came from, and each of those knows
  //what it looks like: deckPhotoHeroFlightShuttle for a swipe card,
  //photoHeroFlightShuttle for a grid tile.
  Widget _maybeHero(Widget child) =>
      heroTag == null ? child : Hero(tag: heroTag!, child: child);

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
  //set when these buttons are the card's buttons, arriving from above
  final Object? heroTag;

  const _DecisionBar({
    required this.onDecide,
    required this.showSuperLike,
    this.heroTag,
  });

  //ONLY THE ROW FLIES, not the bar. The gradient behind it belongs to this
  //page - carrying it along would drag a slab of background colour across the
  //photo for the whole flight.
  Widget _maybeHero(Widget child) => heroTag == null
      ? child
      : Hero(tag: heroTag!, createRectTween: straightHeroPath, child: child);

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
      child: _maybeHero(
        Row(
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
      ),
    );
  }
}
