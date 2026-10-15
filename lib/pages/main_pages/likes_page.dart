//Who liked you, and the decision to like them back.
//
//A TAP OPENS THE SAME PAGE THE DECK OPENS. It used to be a dialog: the swipe
//card shrunk into a floating box with two buttons under it, which showed a
//photo and a name and nothing else - no bio, no answers, no other photos. You
//cannot decide about a person from that. Now the tile's photo grows into the
//full, scrollable profile (profileDetailRoute), exactly as the deck does, so
//there is one profile layout in the app and one way to reach it.
//
//THE DECISION COMES BACK FROM THE PAGE, as it does on home: the page pops a
//ProfileDecision and this page owns the backend call, the match dialog and
//removing the tile. Nothing here is a second copy of the profile UI.
//
//SOMEONE WHO LIKED YOU IS ALREADY HALF A MATCH, so liking back matches
//immediately - registerSwipe returns true and the dialog fires. A pass is
//remembered too: the /likes query only re-surfaces them if they like you again
//afterwards. That is also why the profile opens here with NO super like
//button: the star exists to get you noticed by someone who has not seen you,
//and this person already has.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/liker_model.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/pages/main_pages/profile_detail_page.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/app_dialog.dart';
import 'package:foitifinder/widgets/photo_card.dart';

//two across: big enough to recognise a face, small enough to scan a page of
//them. The ratio is the one a portrait photo wants.
const int _kGridColumns = 2;
const double _kTileAspect = 0.75;
const double _kGridGap = 8;

//where the name sits on a tile. Constants because the flight redraws it in
//the same place over a rect that is in mid-air, with no tile to measure.
const double _kTileLabelInset = 10;
const double _kTileLabelBottom = 8;

class LikesPage extends StatefulWidget {
  const LikesPage({super.key});

  @override
  State<LikesPage> createState() => LikesPageState();
}

//PUBLIC on purpose: main_screen.dart holds a GlobalKey to it and calls
//loadLikes() when an FCM 'new_like' arrives, so the page refreshes without
//being visited.
class LikesPageState extends State<LikesPage> {
  List<LikerModel> _likes = [];
  //true until the first load finishes, so the page does not flash "no likes"
  //at someone who has them
  bool _loading = true;

  AppLocalizations get text => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    loadLikes();
  }

  Future<void> loadLikes() async {
    try {
      final likes = await ApiService.getLikes(
        FirebaseAuth.instance.currentUser!.uid,
      );
      if (!mounted) return;
      setState(() {
        _likes = likes;
        _loading = false;
      });
    } catch (_) {
      //a failed refresh keeps whatever is already on screen; the empty state
      //is reached by having no likes, not by the network being down
      if (mounted) setState(() => _loading = false);
    }
  }

  //ties a grid tile's photo to the header photo of the profile page.
  //
  //The 'liker-' prefix matters: the home deck is built at the same time as
  //this page inside main_screen's PageView, and two Heroes sharing a tag in
  //one route is a crash - the deck uses 'card-photo-<id>' for the same person.
  Object _photoHeroTag(LikerModel liker) => 'liker-photo-${liker.id}';

  //Open the whole profile, then act on the decision it pops.
  Future<void> _openProfile(LikerModel liker) async {
    final decision = await Navigator.push<ProfileDecision>(
      context,
      profileDetailRoute(
        userId: liker.id,
        photoHeroTag: _photoHeroTag(liker),
        //pass or like back, nothing in between
        showSuperLike: false,
        //the tile already has a face and a name, so the page opens with them
        //rather than a spinner; the rest arrives a moment later
        preview: PublicProfile(
          id: liker.id,
          name: liker.name,
          age: liker.age,
          photos: [ProfilePhoto(url: liker.imageUrl)],
        ),
      ),
    );
    if (!mounted || decision == null) return;

    switch (decision) {
      case ProfileDecision.pass:
        await _decide(liker, "pass");
      //the page has no star, so this cannot arrive; treated as a like rather
      //than dropped, because losing a decision silently is the worse failure
      case ProfileDecision.superLike:
      case ProfileDecision.like:
        await _decide(liker, "like");
    }
  }

  //Register the swipe, drop the tile, and celebrate a match.
  //
  //THE TILE GOES FIRST. A decision has been made either way, so leaving the
  //person on screen while the request is in flight invites a second tap on
  //someone already decided about.
  Future<void> _decide(LikerModel liker, String action) async {
    setState(() => _likes.removeWhere((l) => l.id == liker.id));

    bool isMatch = false;
    try {
      isMatch = await ApiService.registerSwipe(
        FirebaseAuth.instance.currentUser!.uid,
        liker.id,
        action,
      );
    } catch (_) {
      //TODO: a dropped swipe is silently lost here, exactly as on the deck.
      //Both want a retry queue rather than two separate patches.
    }

    if (!isMatch || !mounted) return;
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.itsAMatch),
        content: Text("${text.matchText1}${liker.name}${text.matchText2}"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text("FoitiFinder"),
      ),
      body: RefreshIndicator(
        onRefresh: loadLikes,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _likes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_likes.isEmpty) {
      //still a scroll view, or RefreshIndicator has nothing to pull on - which
      //is exactly the state you most want to refresh
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                text.noLikes,
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

    //the grid IS the page's scroll view now: it was wrapped in a
    //SingleChildScrollView with shrinkWrap, which builds every tile at once
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(_kGridGap, _kGridGap, _kGridGap, 24),
      itemCount: _likes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kGridColumns,
        crossAxisSpacing: _kGridGap,
        mainAxisSpacing: _kGridGap,
        childAspectRatio: _kTileAspect,
      ),
      itemBuilder: (_, index) {
        final liker = _likes[index];
        return _LikerTile(
          liker: liker,
          heroTag: _photoHeroTag(liker),
          onTap: () => _openProfile(liker),
        );
      },
    );
  }
}

//One face in the grid: the photo, and the name over it.
//
//THE NAME FLIES WITH THE PHOTO AND FADES OFF IT, the same way the swipe
//card's pills do - it is inside the Hero, and photoHeroShuttle redraws it on
//top of the flying photo. The profile page writes the name in its own place,
//so carrying this one all the way there would mean two of them.
class _LikerTile extends StatelessWidget {
  final LikerModel liker;
  final Object heroTag;
  final VoidCallback onTap;

  const _LikerTile({
    required this.liker,
    required this.heroTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    //built once and used twice: in the tile, and by the flight that fades it
    //off the photo. A widget is immutable configuration, so sharing it is
    //free - it is the same description drawn in two places.
    final Widget label = Positioned(
      left: _kTileLabelInset,
      right: _kTileLabelInset,
      bottom: _kTileLabelBottom,
      child: Text(
        "${liker.name}, ${liker.age}",
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
    final placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    //kCardRadius, not a radius of its own: the flight shuttle interpolates
    //from that exact value down to 0, so any other number makes the corners
    //jump the instant the photo lifts off
    return GestureDetector(
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
              CachedNetworkImage(
                //the same URL the profile page's header asks for, so it is
                //already in the cache when the Hero lands
                imageUrl: liker.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: kPhotoTopScrim),
              ),
              label,
            ],
          ),
        ),
      ),
    );
  }
}
