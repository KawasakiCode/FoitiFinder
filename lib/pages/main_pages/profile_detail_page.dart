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
//THE PHOTO FLIES ABOVE EVERYTHING, and nothing here can change that. A hero
//flight is an OverlayEntry inserted into the Navigator's overlay
//(heroes.dart), which sits above every route - so while the photo is in the
//air no widget on this page can paint over it, however they are stacked. The
//deck card is nearly the whole screen, so for most of that flight the photo
//covers where the profile is arriving; anything the card itself should be
//seen to lose on the way (its pills, its darkening) therefore has to travel
//WITH the photo, which is what deckPhotoHeroFlightShuttle is for.
//
//The profile under it rides the route's own animation in both directions: in
//from the right as the page opens, and back out along the same path when it
//is popped. The buttons are the exception - see the note in build.
//
//Everything under the photo is ProfileDetailsBody - the same widget the user's
//own preview draws, so what they arranged is what a stranger reads.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/pages/profile_pages/view_profile/profile_details_body.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/app_dialog.dart';
import 'package:foitifinder/widgets/report_sheet.dart';
import 'package:foitifinder/widgets/photo_card.dart';
import 'package:foitifinder/widgets/profile_photo.dart';

//the body's slide, for tests that need to watch it
const Key kProfileBodySlideKey = Key('profile-body-slide');

//what the page pops with, so the deck knows what to do next.
//superLike is never popped when the page is opened without that button - see
//showSuperLike below.
//A CONSIDERED NO IS ITS OWN DECISION, not a pass with a different label.
//Both leave the deck the same way; only one of them was thought about, and
//that difference is worth keeping for ranking - see UserSwipes.action.
enum ProfileDecision { pass, superLike, like, notInterested }

//How the page is opened, kept beside the layout it depends on.
Route<ProfileDecision> profileDetailRoute({
  required int userId,
  required PublicProfile preview,
  required Object photoHeroTag,
  Object? actionsHeroTag,
  bool showSuperLike = true,
  //false once the week's two are spent: the star greys rather than vanishing,
  //and the tap still explains why (see AppColors.spentGradient)
  bool superLikeAvailable = true,
  bool decisions = true,
  Widget? footer,
  //ONLY SET FOR A FINISHED MATCH, which is the only state that can be
  //removed. Passed in rather than decided here: this page shows whoever it is
  //given and knows nothing about matches, and that is worth keeping - the
  //alternative is a profile page that has to ask what kind of thing it is
  //looking at before it can draw its own menu.
  VoidCallback? onRemoveMatch,
  //ZERO WHEN THE PAGE SHOULD ALREADY BE THERE. A tapped notification is
  //asking for this profile, not for the matches page - so animating in from
  //the grid replays, on top of the app launching, a journey the user never
  //made. The flight runs on this animation too, so zero means the photo is
  //simply in place rather than flying from a tile that was never on screen.
  //
  //THE EXIT IS LEFT ALONE: pressing back IS a journey, and it lands on the
  //grid, which is where the reverse flight belongs.
  Duration transitionDuration = const Duration(milliseconds: 680),
}) {
  return PageRouteBuilder<ProfileDecision>(
    //THIS IS THE FLIGHT'S DURATION TOO. A hero flight runs on the route's
    //animation, so these two numbers are what makes the photo and the buttons
    //travel at the speed they do.
    transitionDuration: transitionDuration,
    reverseTransitionDuration: const Duration(milliseconds: 520),
    pageBuilder: (_, _, _) => ProfileDetailPage(
      userId: userId,
      preview: preview,
      photoHeroTag: photoHeroTag,
      actionsHeroTag: actionsHeroTag,
      showSuperLike: showSuperLike,
      superLikeAvailable: superLikeAvailable,
      decisions: decisions,
      footer: footer,
      onRemoveMatch: onRemoveMatch,
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

//THE PROFILE RIDES THE ROUTE'S OWN ANIMATION, and has no controller of its
//own. It slides in from the right as the page opens and retraces that exact
//path on the way out, because the route animation runs backwards when the
//page is popped and the same curve is used in both directions.
//
//IT USED TO BE AN AnimationController DRIVEN BY A STATUS LISTENER, and that
//quietly did not work at all. The hero controller parks a pushed route
//OFFSTAGE for one frame to measure where the flight is landing
//(heroes.dart: `toRoute.offstage = toRoute.animation!.value == 0.0`), and
//while a route is offstage ModalRoute.animation is swapped for
//kAlwaysCompleteAnimation (routes.dart). The page's first build happens in
//exactly that frame, so the animation claimed to be COMPLETED: the listener
//was never attached, the content slid in immediately instead of after the
//flight, and nothing ever reversed it - the body simply stopped being
//painted when the route was disposed. Hence a slide in and no slide out.
//
//The lesson is in the only place it still matters, below: a route animation
//reading `completed` is not the same as the transition having finished.

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
  //false once the week's two super likes are spent: the star greys instead of
  //vanishing, and the tap still explains why
  final bool superLikeAvailable;
  //FALSE WHEN THE DECISION IS SOMEBODY ELSE'S PAGE. The match page asks one
  //question and asks it there; a second set of like/pass buttons under the
  //profile would be a different answer to the same thing. The page is then
  //purely something to read - which is the point of opening it from a match
  //you swiped on weeks ago and have forgotten.
  final bool decisions;
  //PINNED WHERE THE LIKE/PASS BUTTONS WOULD BE, for a profile opened from
  //somewhere that is not a decision. The matches page passes the match's own
  //action here - share, waiting, or the handle - so a match is read the same
  //way every other person in the app is read, instead of on a screen of its
  //own. Nothing flies into this one, so it is drawn plainly.
  final Widget? footer;
  //Adds 'Remove match' to the menu, and is what performs it. Null everywhere
  //else, which is how the menu knows not to offer it.
  final VoidCallback? onRemoveMatch;

  const ProfileDetailPage({
    super.key,
    required this.userId,
    required this.preview,
    this.photoHeroTag,
    this.actionsHeroTag,
    this.showSuperLike = true,
    this.superLikeAvailable = true,
    this.decisions = true,
    this.footer,
    this.onRemoveMatch,
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

    final ModalRoute<Object?>? route = ModalRoute.of(context);
    //kAlwaysCompleteAnimation when there is no route animation at all, which
    //is a page that was simply put on screen - it should look settled, not
    //mid-slide
    final Animation<double> routeAnimation =
        route?.animation ?? kAlwaysCompleteAnimation;
    //SAME CURVE IN BOTH DIRECTIONS, so the way out retraces the way in rather
    //than taking a different path (CurvedAnimation falls back to `curve` when
    //reverseCurve is null; a reverseCurve is 1 - c(1 - t), a different set of
    //positions). The route animation runs backwards on a pop, so this is the
    //whole of the slide-out.
    final Animation<Offset> bodySlide =
        Tween<Offset>(begin: const Offset(0.35, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: routeAnimation, curve: Curves.fastOutSlowIn),
        );
    final Animation<double> bodyFade = CurvedAnimation(
      parent: routeAnimation,
      curve: Curves.easeOut,
    );

    return Scaffold(
      //the photo runs under the bar and up to the very top of the screen
      extendBodyBehindAppBar: true,
      //LAID OUT, NOT OVERLAID. The footer used to be a Positioned child of
      //the Stack below, floating over the scroll view, and the scroll view
      //ended with a fixed 120px spacer to clear it. That number was measured
      //against the like/pass bar; MatchActionBar in its revealed state is
      //taller - a title, the handle in large type and two buttons - so the
      //last card on a connected profile was cut in half by it and could not
      //be scrolled into view at all.
      //
      //In this slot the Scaffold shortens the body by whatever the bar
      //actually measures, so nothing has to guess. The decision bar stays in
      //the Stack because it flies there from the deck's card and a Hero needs
      //its destination to sit still.
      bottomNavigationBar: widget.footer,
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
                  //in with the page, and back out the same way on a pop
                  child: FadeTransition(
                    opacity: bodyFade,
                    child: SlideTransition(
                      //named so a test can watch it move - this slide has
                      //broken twice, both times silently
                      key: kProfileBodySlideKey,
                      position: bodySlide,
                      child: ProfileDetailsBody(profile: _profile),
                    ),
                  ),
                ),
                //CLEAR OF THE DECISION BAR, which is the only thing still
                //pinned over this scroll view. A footer is laid out by the
                //Scaffold instead (see bottomNavigationBar), so it needs no
                //allowance here - and when there is neither, this is just
                //breathing room at the end of a profile.
                SizedBox(height: widget.decisions ? 120 : 24),
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
              //TWO WAYS IN, AND THEY CANNOT SHARE AN ANIMATION. When the
              //buttons fly down from a card they must not be moved by this
              //page at all - a Hero measures its destination where it
              //currently sits, so a bar inside a SlideTransition would be
              //measured mid-slide and the buttons would land in the wrong
              //place. All this side does is keep the real pair invisible and
              //untappable until the copy has arrived.
              child: widget.actionsHeroTag != null
                  ? AnimatedBuilder(
                      animation: routeAnimation,
                      builder: (context, child) {
                        //COMPLETED IS NOT ARRIVED. The hero controller parks
                        //this route offstage for a frame to measure the
                        //flight, and an offstage route reports
                        //kAlwaysCompleteAnimation - so the offstage flag has
                        //to be checked too, or the real buttons appear for a
                        //frame beside the copy that is about to fly.
                        final landed =
                            routeAnimation.isCompleted &&
                            !(route?.offstage ?? false);
                        return IgnorePointer(
                          ignoring: !landed,
                          child: Opacity(opacity: landed ? 1 : 0, child: child),
                        );
                      },
                      child: _DecisionBar(
                        onDecide: _decide,
                        showSuperLike: widget.showSuperLike,
                        superLikeAvailable: widget.superLikeAvailable,
                        heroTag: widget.actionsHeroTag,
                      ),
                    )
                  //nothing to fly from (the likes grid), so it arrives AND
                  //leaves with the profile, on the same animation
                  : FadeTransition(
                      opacity: bodyFade,
                      child: SlideTransition(
                        position: bodySlide,
                        child: _DecisionBar(
                          onDecide: _decide,
                          showSuperLike: widget.showSuperLike,
                          superLikeAvailable: widget.superLikeAvailable,
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
            //ONLY FOR A FINISHED MATCH. decline is the way out of every other
            //state and it tells whoever was waiting; this one tells nobody,
            //so offering it earlier would be a silent way to abandon somebody
            //mid-exchange. The server refuses it too (409) - this just does
            //not put it in front of anyone.
            if (widget.onRemoveMatch != null)
              ListTile(
                leading: const Icon(Icons.heart_broken_outlined),
                title: Text(text.removeMatch),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmRemoveMatch();
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(text.reportUser),
              onTap: () {
                Navigator.pop(sheetContext);
                _report();
              },
            ),
          ],
        ),
      ),
    );
  }

  //AFTER A MATCH IS WHAT onRemoveMatch ALREADY TELLS US. It is non-null only
  //for a revealed match, which is also the only state where the harassment
  //group makes sense - that group is about what somebody did once they had
  //your Instagram handle. The endpoint refuses it without a match too, so
  //this decides what is OFFERED rather than what is allowed.
  void _report() {
    showReportSheet(
      context,
      reportedUserId: widget.userId,
      afterMatch: widget.onRemoveMatch != null,
      //REPORTING TAKES THEM OUT OF THE DECK and off this user's match list,
      //so there is nothing left on this page to look at.
      onReported: () {
        if (mounted) Navigator.pop(context);
      },
      //THE DECK ONLY, which is what `decisions` means: this page can send a
      //decision back to whoever opened it. The matches page opens profiles
      //with decisions off and discards what comes back, so the option used to
      //sit there doing nothing at all when tapped.
      //
      //AND IT WOULD BE THE WRONG QUESTION THERE. 'Not interested' in somebody
      //you have already matched with is not a pass - you cannot un-see a
      //handle, and acting on it would mean destroying a match through a
      //button that says nothing about destroying anything. That is what
      //'Remove match' is for, two rows up the same menu, with a warning on it.
      onNotInterested: widget.decisions
          ? () {
              if (mounted) {
                Navigator.pop(context, ProfileDecision.notInterested);
              }
            }
          : null,
    );
  }

  //TWO TAPS, because this one cannot be undone: the match is the only route
  //back to somebody whose handle you did not save, and there is no list of
  //removed matches to restore it from.
  //
  //THE DIALOG SAYS THE TWO THINGS PEOPLE ACTUALLY WONDER - that it cannot be
  //undone, and that the other person is not told and keeps their own copy.
  //The second half matters more than it looks: without it, removing a match
  //reads like doing something TO them rather than tidying your own list.
  Future<void> _confirmRemoveMatch() async {
    final text = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.removeMatchTitle),
        content: Text(text.removeMatchBody(_profile.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              text.removeMatchAction,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    //THE CALLER OWNS THE REQUEST AND THE LIST BEHIND IT, so this page only
    //closes itself - it has nothing left to show once the match is gone.
    widget.onRemoveMatch?.call();
    if (mounted) Navigator.pop(context);
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
    if (url == null) return const PhotoMissingBox();

    //the scrim is INSIDE the Hero, so the back arrow and the menu keep the
    //same darkening under them the whole way up from the card, instead of it
    //vanishing for the flight and snapping back on landing
    return _maybeHero(
      Stack(
        fit: StackFit.expand,
        children: [
          PersonPhoto(
            url: url,
            //ARRIVING FROM A LIKES TILE, the only copy of this photo in
            //memory is the tile's small one, so that is what stands in while
            //the full-size decode runs: a slightly soft version of the right
            //face beats an empty box. Arriving from a swipe card this never
            //builds - the card decoded this exact key already.
            whileLoading: PersonPhoto(
              url: url,
              decodeWidth: kThumbDecodeWidth,
            ),
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
  final bool superLikeAvailable;
  //set when these buttons are the card's buttons, arriving from above
  final Object? heroTag;

  const _DecisionBar({
    required this.onDecide,
    required this.showSuperLike,
    required this.superLikeAvailable,
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
                //grey once the week's two are gone; still pressable, since
                //the tap is what explains why
                gradient: superLikeAvailable
                    ? AppColors.superLikeGradient
                    : AppColors.spentGradient,
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
