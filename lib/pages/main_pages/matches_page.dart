//Your matches: everyone you and somebody else both said yes to.
//
//THIS WAS THE LIKES PAGE. Hiding who liked you put every match on a page of
//its own and left the deck unable to produce one at all - every payoff in the
//app arrived somewhere other than the screen people actually use. Now likers
//go back into the deck unannounced, a match can happen on any swipe, and this
//page is where they live afterwards.
//
//IT IS ALSO WHY THE BELL NO LONGER CARRIES MATCHES. A stored notification
//existed because the match page was the only entrance to a match: a swipe
//delivered late by the retry queue, or an app killed at the wrong moment,
//stranded it. This list is always reachable and always current, so the
//notification had nothing left to rescue - and it was the row that made
//'match' mean two different things at once.
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
import 'package:foitifinder/widgets/profile_photo.dart';

//two across: big enough to recognise a face, small enough to scan a page of
//them. The ratio is the one a portrait photo wants.
const int _kGridColumns = 2;
const double _kTileAspect = 0.75;
const double _kGridGap = 8;

//where the name sits on a tile. Constants because the flight redraws it in
//the same place over a rect that is in mid-air, with no tile to measure.
const double _kTileLabelInset = 10;
const double _kTileLabelBottom = 8;

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
  Future<void> openMatch(int matchId) async {
    await loadMatches();
    if (!mounted) return;

    //GONE IS A NORMAL OUTCOME, not an error. Between the push being sent and
    //the banner being tapped the other side can have declined, either side
    //can have removed it, and a match left unanswered for three days expires.
    //Landing on the list is then the honest answer: the notification was
    //true when it was sent, and the page says what is true now.
    final match = _matches
        .where((candidate) => candidate.matchId == matchId)
        .firstOrNull;
    if (match == null) return;

    //NO NAVIGATION OF ITS OWN: the same call a tapped tile makes, so a match
    //reached from a banner is the same screen with the same action bar and
    //the same reload behind it.
    await _openProfile(match);
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
  Future<void> _openProfile(MatchModel match) async {
    await Navigator.push<void>(
      context,
      profileDetailRoute(
        userId: match.otherUserId,
        photoHeroTag: _photoHeroTag(match),
        decisions: false,
        footer: MatchActionBar(match: match, onChanged: loadMatches),
        //ONLY ON A FINISHED MATCH, which is the only state with no other way
        //out: decline covers the unanswered ones and the clock covers the
        //expired ones. Passing null for the rest is what keeps the option out
        //of the menu, so the page never has to know what a match is.
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
      appBar: const MainAppBar(title: "FoitiFinder"),
      body: RefreshIndicator(onRefresh: loadMatches, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _matches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_matches.isEmpty) {
      //still a scroll view, or RefreshIndicator has nothing to pull on - which
      //is exactly the state you most want to refresh
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                text.noMatches,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
      slivers: [
        ..._section(text.matchYourTurn, sections.yourTurn),
        ..._section(text.matchesSectionWaiting, sections.waitingOnThem),
        ..._section(text.matchesSectionConnected, sections.connected),
        //LAST, because it is the only section nobody can act on. It is here
        //so a match that ran out is read rather than discovered missing, and
        //it leaves on its own a couple of days later.
        ..._section(text.matchesSectionExpired, sections.expired),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  //A heading and its grid, or nothing at all for an empty section - an
  //explained empty state per section would be three paragraphs of furniture
  //on a page whose job is to show faces.
  List<Widget> _section(String title, List<MatchModel> matches) {
    if (matches.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_kGridGap + 4, 20, _kGridGap, 10),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              //THE COUNT, because the sections push each other down the page
              //and a heading with nothing visible under it reads as a bug
              Text(
                '${matches.length}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: _kGridGap),
        //SliverGrid, not GridView: a GridView inside a scroll view needs
        //shrinkWrap, which builds every tile in every section up front
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _kGridColumns,
            crossAxisSpacing: _kGridGap,
            mainAxisSpacing: _kGridGap,
            childAspectRatio: _kTileAspect,
          ),
          delegate: SliverChildBuilderDelegate(
            childCount: matches.length,
            (_, index) {
              final match = matches[index];
              return _MatchTile(
                match: match,
                heroTag: _photoHeroTag(match),
                onTap: () => _openProfile(match),
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
  final VoidCallback onTap;

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
          fontWeight: FontWeight.w600,
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
    //A LAPSED MATCH READS AS PAST, not as something to press. Dimmed rather
    //than removed, because this tile is the notice that it ran out.
    return Opacity(
      opacity: match.expired ? 0.45 : 1,
      child: GestureDetector(
        onTap: onTap,
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
                //THIS USED TO READ 'Your turn' on every untouched tile, which
                //the heading now says once for the whole group instead of
                //repeating on every face under it.
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
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
    );
  }
}
