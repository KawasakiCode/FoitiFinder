//Your matches: everyone you and somebody else both said yes to.
//
//THE BELL DOES NOT CARRY MATCHES. This list is always reachable and always
//current, so a stored notification about one could only ever be a staler copy
//of a screen the user can simply open - and it would make 'match' mean two
//different things at once. Likers go back into the deck unannounced, a match
//can happen on any swipe, and this page is where they live afterwards.
//
//A TAP OPENS THE SAME PROFILE THE DECK OPENS, with the match's own action
//pinned under it: share, waiting, or their handle. One profile layout in the
//app, one way to reach it, and you can read somebody properly before handing
//over an Instagram handle.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/matches_model.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/pages/main_pages/profile_detail_page.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/main_app_bar.dart';
import 'package:foitifinder/widgets/match_actions.dart';
import 'package:foitifinder/widgets/photo_card.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:foitifinder/widgets/profile_photo.dart';

//two across: big enough to recognise a face, small enough to scan a page of
//them. The ratio is the one a portrait photo wants.
const int _kGridColumns = 2;
const double _kTileAspect = 0.75;
const double _kGridGap = 8;

//where the name sits on a tile. Constants because the flight redraws it in
//the same place over a rect that is in mid-air, with no tile to measure.
const double _kTileLabelInset = 8;
const double _kTileLabelBottom = 8;

const SliverGridDelegate _kGridDelegate =
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _kGridColumns,
      crossAxisSpacing: _kGridGap,
      mainAxisSpacing: _kGridGap,
      childAspectRatio: _kTileAspect,
    );

const EdgeInsets _kSectionHeadingPadding = EdgeInsets.fromLTRB(16, 24, 8, 8);

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => MatchesPageState();
}

//PUBLIC on purpose: main_screen.dart holds a GlobalKey to it and calls
//loadMatches() when a match FCM arrives, so the page is current without
//having been visited.
class MatchesPageState extends State<MatchesPage> {
  List<MatchModel> _matches = [];
  //true until the first load finishes, so the page does not flash "no
  //matches" at someone who has them
  bool _loading = true;
  //ONE PROFILE AT A TIME. home_page has carried this guard for a while for
  //the same reason: Navigator.push is not idempotent, so two calls that
  //arrive before the first route is on screen stack two identical pages, and
  //the first back press then appears to do nothing because what it uncovers
  //looks the same. A tapped notification was the second way to cause that;
  //a fast double tap on a tile is the first.
  bool _openingProfile = false;
  //tiles that have already played their entrance; see Entrance.shouldPlay
  final Set<int> _enteredTiles = {};

  AppLocalizations get text => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    loadMatches();
  }

  //COALESCED, NOT GUARDED. Opening this tab reloads it, so swiping across the
  //three tabs and back fires this several times in a second - and the callers
  //that matter are awaited: RefreshIndicator holds its spinner until the
  //future completes, so returning early would end the animation on a load
  //that is still running. Everybody gets the SAME future instead.
  Future<void>? _inFlight;

  Future<void> loadMatches() =>
      _inFlight ??= _load().whenComplete(() => _inFlight = null);

  Future<void> _load() async {
    try {
      final matches = await ApiService.getMatches(
        uid: FirebaseAuth.instance.currentUser!.uid,
      );
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
      });
    } catch (_) {
      //a failed refresh keeps whatever is already on screen; the empty state
      //is reached by having no matches, not by the network being down
      if (mounted) setState(() => _loading = false);
    }
  }

  //Open one specific match, for a tapped notification.
  //
  //PUBLIC, like loadMatches: main_screen holds a GlobalKey to this state and
  //calls it when a banner is tapped, which can happen while this page has
  //never been looked at.
  //
  //IT RELOADS FIRST. The push arrived while the app was in the background or
  //shut, so whatever is in _matches is from before that - and on a cold start
  //there is nothing in it at all.
  Future<void> openMatch(MatchModel match) async {
    //ALREADY LOADED BY THE CALLER, deliberately. main_screen fetches the
    //match before it switches to this tab, so the list is never shown
    //mid-flight while a request runs - the profile is the first thing the
    //notification puts on screen.
    //
    //NO NAVIGATION OF ITS OWN BEYOND THAT: the same call a tapped tile
    //makes, so a match reached from a banner is the same screen with the same
    //action bar and the same reload behind it.
    await _openProfile(match, instant: true);
  }

  //ties a grid tile's photo to the header photo of the profile page.
  //
  //The 'match-' prefix matters: the home deck is built at the same time as
  //this page inside main_screen's PageView, and two Heroes sharing a tag in
  //one route is a crash - the deck uses 'card-photo-<id>' for the same person.
  Object _photoHeroTag(MatchModel match) => 'match-photo-${match.otherUserId}';

  //Open the whole profile, with this match's action pinned under it.
  //
  //NO ProfileDecision COMES BACK. There is nothing to decide about a person
  //you have already matched with - the decision left is whether to hand over
  //an Instagram handle, and that lives in the bar so it can show the three
  //states the server reports rather than two buttons that mean one thing.
  Future<void> _openProfile(MatchModel match,
      {bool instant = false, Rect? from}) async {
    if (_openingProfile) return;
    _openingProfile = true;
    await Navigator.push<void>(
      context,
      profileDetailRoute(
        userId: match.otherUserId,
        photoHeroTag: _photoHeroTag(match),
        decisions: false,
        //a tapped notification asks for this profile, not for a journey to
        //it; a tapped tile asks for the journey, at a speed that does not
        //depend on how far down the grid it happened to be.
        //
        //SAME NUMBER BOTH WAYS for a tapped tile: the return covers the same
        //ground, so a fixed reverse would snap back after a long flight out.
        //The notification path deliberately differs - it opens with no
        //flight at all and still closes with one.
        transitionDuration: instant
            ? Duration.zero
            : profileFlightDuration(context, from),
        reverseTransitionDuration:
            instant ? null : profileFlightDuration(context, from),
        footer: MatchActionBar(match: match, onChanged: loadMatches),
        //ONLY ON A FINISHED MATCH, which is the only state with no other way
        //out: decline covers the unanswered ones and the clock covers the
        //ones that run out, by deleting them. Passing null for the rest is
        //what keeps the option out of the menu, so the page never has to know
        //what a match is.
        onRemoveMatch: match.revealed ? () => _removeMatch(match) : null,
        //the tile already has a face and a name, so the page opens with them
        //rather than a spinner; the rest arrives a moment later
        preview: PublicProfile(
          id: match.otherUserId,
          name: match.otherUserName,
          age: match.otherUserAge,
          //no photo, no entry: the page draws its own placeholder rather
          //than being handed a URL that is not there
          photos: [
            if (match.imageUrl != null) ProfilePhoto(url: match.imageUrl!),
          ],
        ),
      ),
    );
    _openingProfile = false;
    //sharing or declining while in there changes what this list should say
    if (mounted) await loadMatches();
  }

  //OPTIMISTIC, because the profile page has already closed itself and the
  //grid it closed onto must not still show the match for the length of a
  //request. The reload afterwards is what makes it true rather than merely
  //drawn - and on failure it puts the match back, which is the honest
  //outcome: nothing was removed.
  Future<void> _removeMatch(MatchModel match) async {
    setState(() {
      _matches = _matches
          .where((other) => other.matchId != match.matchId)
          .toList();
    });
    try {
      await ApiService.removeMatch(match.matchId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text.errorOccured)));
      }
    }
    await loadMatches();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //the grid scrolls under the frosted bar
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(child: MainAppBar(title: "FoitiFinder")),
      body: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
        onRefresh: loadMatches,
        child: Crossfade(child: _buildBody()),
      ),
    );
  }

  //The shape of the page before it has anything in it: a heading and a grid
  //of tiles the size the real ones will be.
  Widget _buildSkeleton() {
    return Shimmer(
      key: const ValueKey('loading'),
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          const SliverGlassBarInset(),
          const SliverPadding(
            padding: _kSectionHeadingPadding,
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Bone(width: 96, height: 16),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _kGridGap),
            sliver: SliverGrid(
              gridDelegate: _kGridDelegate,
              delegate: SliverChildBuilderDelegate(
                childCount: 6,
                (_, _) => const Bone(radius: kCardRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _matches.isEmpty) return _buildSkeleton();

    if (_matches.isEmpty) {
      //still a scroll view, or RefreshIndicator has nothing to pull on - which
      //is exactly the state you most want to refresh
      return CustomScrollView(
        key: const ValueKey('empty'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverGlassBarInset(),
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.favorite_border,
              message: text.noMatches,
              actionLabel: text.retry,
              onAction: loadMatches,
            ),
          ),
        ],
      );
    }

    //THREE SECTIONS, IN THE ORDER THE EXCHANGE HAPPENS. One flat grid of
    //faces said nothing about what any of them needed: a match waiting on you
    //and one you have already opened on Instagram looked identical, and the
    //only difference was a small badge on a corner. The step you are at is
    //the thing this page is actually about, so it is the thing it sorts by.
    //
    //THE GROUPING ITSELF IS IN MatchSections, not here: it is a pure function
    //of the list and this page cannot be pumped in a test, so keeping it in
    //the model is the difference between the partition being checked and
    //being hoped for. 'Your turn' arrives already ordered.
    final sections = MatchSections.of(_matches);

    return CustomScrollView(
      key: const ValueKey('grid'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverGlassBarInset(),
        ..._section(text.matchYourTurn, sections.yourTurn),
        ..._section(text.matchesSectionWaiting, sections.waitingOnThem),
        ..._section(text.matchesSectionConnected, sections.connected),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  //A heading and its grid, or nothing at all for an empty section - an
  //explained empty state per section would be three paragraphs of furniture
  //on a page whose job is to show faces.
  List<Widget> _section(String title, List<MatchModel> matches) {
    if (matches.isEmpty) return const [];
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return [
      SliverToBoxAdapter(
        child: Entrance(
          child: Padding(
            padding: _kSectionHeadingPadding,
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: ink,
                  ),
                ),
                const SizedBox(width: 8),
                //THE COUNT, because the sections push each other down the page
                //and a heading with nothing visible under it reads as a bug
                Text(
                  '${matches.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: _kGridGap),
        //SliverGrid, not GridView: a GridView inside a scroll view needs
        //shrinkWrap, which builds every tile in every section up front
        sliver: SliverGrid(
          gridDelegate: _kGridDelegate,
          delegate: SliverChildBuilderDelegate(
            childCount: matches.length,
            (_, index) {
              final match = matches[index];
              return Entrance(
                key: ValueKey(match.matchId),
                order: Entrance.orderFor(index),
                shouldPlay: () => _enteredTiles.add(match.matchId),
                child: _MatchTile(
                  match: match,
                  heroTag: _photoHeroTag(match),
                  onTap: (from) => _openProfile(match, from: from),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }
}

//One face in the grid: the photo, and the name over it.
//
//THE NAME FLIES WITH THE PHOTO AND FADES OFF IT, the same way the swipe
//card's pills do - it is inside the Hero, and photoHeroShuttle redraws it on
//top of the flying photo. The profile page writes the name in its own place,
//so carrying this one all the way there would mean two of them.
class _MatchTile extends StatelessWidget {
  final MatchModel match;
  final Object heroTag;
  //TAKES WHERE THE TILE IS, so the page it opens can time the flight to the
  //distance it has to cover - see profileFlightDuration.
  final void Function(Rect? from) onTap;

  const _MatchTile({
    required this.match,
    required this.heroTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    //built once and used twice: in the tile, and by the flight that fades it
    //off the photo. A widget is immutable configuration, so sharing it is
    //free - it is the same description drawn in two places.
    final Widget label = Positioned(
      left: _kTileLabelInset,
      right: _kTileLabelInset,
      bottom: _kTileLabelBottom,
      child: Text(
        match.otherUserAge == null
            ? match.otherUserName
            : "${match.otherUserName}, ${match.otherUserAge}",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: Colors.white,
          shadows: [
            //cheaper than a second gradient, and enough to keep the name
            //readable over a bright photo
            Shadow(blurRadius: 8, color: Color(0xCC000000)),
          ],
        ),
      ),
    );

    //kCardRadius, not a radius of its own: the flight shuttle interpolates
    //from that exact value down to 0, so any other number makes the corners
    //jump the instant the photo lifts off
    return SpringPress(
      child: GestureDetector(
        onTap: () {
          //MEASURED AT TAP TIME, not held in state: the grid scrolls and
          //resizes under this, so a position captured when the tile was built
          //would describe where it was built, not where it is.
          final box = context.findRenderObject() as RenderBox?;
          onTap(box == null || !box.hasSize
              ? null
              : box.localToGlobal(Offset.zero) & box.size);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kCardRadius),
            boxShadow: AppShadows.card,
          ),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(kCardRadius),
          //the photo, its scrim AND the name are all inside the Hero, so the
          //three of them leave the tile together at lift-off
          child: Hero(
            tag: heroTag,
            flightShuttleBuilder: photoHeroShuttle(furniture: [label]),
            child: Stack(
              fit: StackFit.expand,
              children: [
                //a tile is half the screen wide, so it decodes at the
                //thumbnail width; the profile header it flies to uses this copy
                //as its stand-in while the full-size one decodes
                PersonPhoto(
                  url: match.imageUrl,
                  decodeWidth: kThumbDecodeWidth,
                  missingIconSize: 40,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: kPhotoTopScrim),
                ),
                label,
                //THEY HAVE ALREADY SAID YES, so this one is somebody waiting on
                //an answer rather than a match they do not know they have. It
                //is the only thing the section heading above cannot say: both
                //kinds sit under 'Your turn', because both need the same press.
                //
                //Outside the Hero deliberately: it belongs to this list, not to
                //the profile the photo flies to, and carrying it along would
                //leave it hanging over a page that says the same thing properly
                //at the bottom.
                if (match.theyAreWaitingOnMe)
                  Positioned(
                    top: _kTileLabelInset,
                    left: _kTileLabelInset,
                    child: Container(
                      height: 24,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.matchTheySaidYes,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
