//One profile card in the swipe deck: the photo, who it is, and the actions.
//
//The whole card is the photo. Everything else is drawn ON it - name and age at
//the top, stats and the three buttons at the bottom - with a dark gradient at
//each end so white text stays readable over a bright photo.
//
//A TAP OPENS THE WHOLE PROFILE. It used to flick between this person's photos,
//left half back and right half forward, with thin bars along the top counting
//them - both are gone. The card shows one photo and one question: do you want
//to know more? The rest of the photos live on the profile page, where they sit
//beside the text that explains them.
//
//Dragging still belongs to the deck above (pass / like / super like), so this
//is a GestureDetector with onTap and nothing else.
//
//OPENING THE PROFILE TAKES THE CARD APART, rather than covering it: the photo
//grows into the page header, the three buttons travel down and become the
//page's buttons (both Heroes, matched by tag), and the stat pills ride up with
//the photo while fading out.
//
//THE PILLS FLY WITH THE PHOTO, which is why they are inside its Hero and are
//redrawn by the flight shuttle. A hero flies in the navigator's overlay, above
//every page, so anything left behind in the deck is hidden underneath it - the
//pills were fading where nobody could see them. Drawn by the shuttle they are
//on top of the photo, which is the whole point of fading them. The card's
//bottom darkening travels the same way and for the same reason: it belongs to
//the card, the page header has none, so it fades out over the flight instead
//of blinking off at lift-off.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/models/card_data_model.dart';
import 'package:foitifinder/theme/app_colors.dart';

//how round the card is; the deck and the photo clip share it
const double kCardRadius = 24;

//How far into the flight the card's own furniture - the pills and the bottom
//darkening - has finished fading. Early, because they belong to a card and the
//thing flying stops looking like a card almost immediately.
const double kCardFurnitureFadeEnd = 0.4;

//Where the pills sit above the bottom of the photo: clear of the buttons (58)
//plus the gap between them (14) plus the card's own bottom inset (16).
//
//A number rather than a Column, because the shuttle has to put a copy of them
//in exactly the same place over a rect that is in mid-flight, and there is no
//Column out there to ask.
const double kStatsBottomInset = 16 + 58 + 14;
const double kCardSideInset = 16;

//A straight line between two rects, for a Hero that should simply travel.
//
//MaterialApp's hero controller arcs flights along a curve, which is right for
//a photo growing across the screen and wrong for the button row: an arc on a
//short vertical move reads as a wobble sideways. The buttons move down.
RectTween straightHeroPath(Rect? begin, Rect? end) =>
    RectTween(begin: begin, end: end);

//THREE PHOTOS MINIMUM, SIX MAXIMUM.
//
//Three because the profile page is built around them: one photo sits after the
//answers, one after the hobbies, the rest at the end. With a single photo that
//page is a wall of cards with nothing to break it up - and the swipe card asks
//"want to see more?", which only works when there is more. It is also a cheap
//honesty signal: one photo is what a half-hearted or fake account has.
//
//Enforced at signup, in the edit grid, and by /photos/sync - the last one is
//what makes it a rule rather than a suggestion.
const int kMinPhotos = 3;
const int kMaxPhotos = 6;

//THE SCRIM TRAVELS WITH THE PHOTO. Drawn inside the Hero on both ends - here
//and on the profile page - so it is present for the whole flight. Left outside
//it, the darkening vanished the instant the photo lifted off and snapped back
//when it landed.
const LinearGradient kPhotoTopScrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0.0, 0.3],
  colors: [Color(0x8C000000), Color(0x00000000)],
);

//The darkening under the pills and the buttons. Unlike the top scrim this one
//is the CARD'S, not the photo's - the profile page puts its controls
//elsewhere - so it fades out during the flight rather than landing on the page
//header.
const LinearGradient kPhotoBottomScrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0.5, 1.0],
  colors: [Color(0x00000000), Color(0xD9000000)],
);

//The widget that actually flies between a card and a profile page.
//
//Without this, Flutter uses the DESTINATION's child for the whole flight - so
//the corners went square the moment the photo lifted, and on the way back they
//only rounded once it had landed. Here the radius is interpolated instead, and
//the scrim rides along, so the shape changes while it moves.
Widget photoHeroFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  //ONE TWEEN FOR BOTH DIRECTIONS, and it must not be flipped by hand: the
  //flight animation itself already runs 0 -> 1 opening and 1 -> 0 closing. A
  //reversed tween on a reversed animation cancels out, which is why the photo
  //used to land back on the card still square.
  //
  //  opening:  t 0 -> 1   gives  24 -> 0   (card corners to full bleed)
  //  closing:  t 1 -> 0   gives   0 -> 24  (full bleed back to card corners)
  final Animation<double> radius = Tween<double>(
    begin: kCardRadius,
    end: 0,
  ).animate(CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn));

  //both ends draw the same thing (photo + scrim), so either Hero's child will
  //do; the destination's is the one whose size the flight is heading for
  final Widget child = toContext.widget is Hero
      ? (toContext.widget as Hero).child
      : const SizedBox.shrink();

  return AnimatedBuilder(
    animation: radius,
    builder: (context, _) => ClipRRect(
      borderRadius: BorderRadius.circular(radius.value),
      child: child,
    ),
  );
}

//The deck's flight: the photo, plus the card furniture fading off it.
//
//IT MUST LIVE ON THE CARD, not on the profile page. Flutter picks the
//DESTINATION hero's shuttle first (heroes.dart: `toHero.widget
//.flightShuttleBuilder ?? fromHero.widget...`), so a shuttle declared on the
//page would also be used for the flight out of the likes grid - and a grid
//tile has no pills to fade. Each source describes its own flight; the page's
//header declares none.
Widget deckPhotoHeroFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  //0 is the card end of the flight and 1 is the page end, whichever way it is
  //travelling - see the note in photoHeroFlightShuttle.
  final Animation<double> radius = Tween<double>(
    begin: kCardRadius,
    end: 0,
  ).animate(CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn));

  //solid at the card end, gone shortly after. Opening fades it out; closing
  //runs the same animation backwards, so it fades back in and is already
  //solid when the photo lands on the card.
  final Animation<double> furniture = Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(
      parent: animation,
      curve: const Interval(0, kCardFurnitureFadeEnd, curve: Curves.easeOut),
    ),
  );

  //THE BARE PHOTO COMES FROM THE PAGE'S END of the flight. The card's own hero
  //child carries the pills and the darkening, and drawing that would put a
  //second, never-fading copy underneath the ones this shuttle animates.
  final BuildContext pageContext = direction == HeroFlightDirection.push
      ? toContext
      : fromContext;
  final Widget photo = pageContext.widget is Hero
      ? (pageContext.widget as Hero).child
      : const SizedBox.shrink();

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) => ClipRRect(
      borderRadius: BorderRadius.circular(radius.value),
      child: Stack(
        fit: StackFit.expand,
        children: [
          photo,
          Opacity(
            opacity: furniture.value,
            child: const DecoratedBox(
              decoration: BoxDecoration(gradient: kPhotoBottomScrim),
            ),
          ),
          //positioned against the rect being flown, so at lift-off they are
          //exactly where the card had them
          Positioned(
            left: kCardSideInset,
            right: kCardSideInset,
            bottom: kStatsBottomInset,
            child: Opacity(
              opacity: furniture.value,
              child: const _StatSlots(),
            ),
          ),
        ],
      ),
    ),
  );
}

class PhotoCard extends StatefulWidget {
  final CardData card;
  //Ties this card's photo to the header photo of the profile page, so opening
  //a profile grows the photo out of the card instead of sliding a new screen
  //over it. Null on the cards behind: only the top one is ever opened, and two
  //Heroes sharing a tag is a crash.
  final Object? photoHeroTag;
  //Ties this card's three buttons to the profile page's button bar, so they
  //slide down into it instead of the page's bar appearing from nowhere. Null
  //on the cards behind, for the same reason photoHeroTag is.
  final Object? actionsHeroTag;
  //null on the cards stacked behind: only the top card acts
  final VoidCallback? onOpen;
  final VoidCallback? onPass;
  final VoidCallback? onSuperLike;
  final VoidCallback? onLike;

  const PhotoCard({
    super.key,
    required this.card,
    this.photoHeroTag,
    this.actionsHeroTag,
    this.onOpen,
    this.onPass,
    this.onSuperLike,
    this.onLike,
  });

  @override
  State<PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<PhotoCard> {
  //only photo 0 is shown here; the rest are on the profile page
  String get _photo => widget.card.photos.isNotEmpty
      ? widget.card.photos.first
      : "https://picsum.photos/400/600";

  @override
  void initState() {
    super.initState();
    _precacheRemainingPhotos();
  }

  //function to precache the users other photos
  void _precacheRemainingPhotos() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.card.photos.length > 1) {
        for (int i = 1; i < widget.card.photos.length; i++) {
          if (i > 5) break;
          precacheImage(
            CachedNetworkImageProvider(widget.card.photos[i]),
            context,
          );
        }
      }
    });
  }

  //The buttons fly as themselves - no custom shuttle, because both ends draw
  //the same row at the same sizes, so there is nothing to interpolate but the
  //rect. Only the path is overridden, to a straight one.
  Widget _maybeActionsHero(Widget child) => widget.actionsHeroTag == null
      ? child
      : Hero(
          tag: widget.actionsHeroTag!,
          createRectTween: straightHeroPath,
          child: child,
        );

  //Only the top card flies; the ones behind are drawn plainly.
  Widget _maybeHero(Widget child) => widget.photoHeroTag == null
      ? child
      : Hero(
          tag: widget.photoHeroTag!,
          flightShuttleBuilder: deckPhotoHeroFlightShuttle,
          child: child,
        );

  @override
  Widget build(BuildContext context) {
    //age and job on one line under the name, either half optional
    final subtitle = [
      if (widget.card.age != null) '${widget.card.age}',
      if ((widget.card.job ?? '').trim().isNotEmpty) widget.card.job!.trim(),
    ].join('  ·  ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(kCardRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          //first layer: the photo, the scrims and the pills, all together,
          //because all of them have to be IN the flight - what stays behind
          //in the deck is hidden under the flying photo anyway
          _maybeHero(
            Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: _photo,
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.grey),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: kPhotoTopScrim),
                ),
                //the bottom darkening belongs to this card alone, so it leaves
                //with it: the shuttle fades it off during the flight
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: kPhotoBottomScrim),
                ),
                //and the pills sit on it, in the place the shuttle redraws
                //them in - kStatsBottomInset is that place
                const Positioned(
                  left: kCardSideInset,
                  right: kCardSideInset,
                  bottom: kStatsBottomInset,
                  child: _StatSlots(),
                ),
              ],
            ),
          ),

          //third layer: a tap anywhere opens the profile. Translucent so the
          //drag above still gets the gesture, and the buttons below still get
          //their taps.
          GestureDetector(
            onTap: widget.onOpen,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),

          //fourth layer: who this is, at the top
          Positioned(
            top: 28,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          //fifth layer: the actions. The pills used to share this Column and
          //now live in the photo's Hero above - kStatsBottomInset is what
          //keeps them the same distance apart as the Column did.
          Positioned(
            left: kCardSideInset,
            right: kCardSideInset,
            bottom: kCardSideInset,
            child: _maybeActionsHero(
              _CardActions(
                onPass: widget.onPass,
                onSuperLike: widget.onSuperLike,
                onLike: widget.onLike,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//PLACEHOLDERS. Six empty pills where the compatibility stats will go - shared
//tags, same university, whatever the matching work decides to surface. Drawn
//now so the card's proportions are the real ones, and so nothing below them
//moves when the content arrives.
class _StatSlots extends StatelessWidget {
  const _StatSlots();

  static const int _count = 6;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < _count; i++)
          Container(
            width: 62,
            height: 30,
            decoration: BoxDecoration(
              //a frosted pill: legible over any photo without hiding it
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
          ),
      ],
    );
  }
}

//Pass, super like, like - in that order, on the card itself rather than under
//it, so the deck owns the whole screen.
class _CardActions extends StatelessWidget {
  final VoidCallback? onPass;
  final VoidCallback? onSuperLike;
  final VoidCallback? onLike;

  const _CardActions({this.onPass, this.onSuperLike, this.onLike});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SwipeActionButton(
          icon: Icons.close,
          gradient: AppColors.passGradient,
          size: 58,
          onPressed: onPass,
        ),
        SwipeActionButton(
          icon: Icons.star,
          gradient: AppColors.superLikeGradient,
          size: 48,
          onPressed: onSuperLike,
        ),
        SwipeActionButton(
          icon: Icons.favorite,
          gradient: AppColors.likeGradient,
          size: 58,
          onPressed: onLike,
        ),
      ],
    );
  }
}

//Shared with the profile page behind a card, so the same three buttons are
//literally the same widget wherever a decision is made.
class SwipeActionButton extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final double size;
  final VoidCallback? onPressed;

  const SwipeActionButton({
    super.key,
    required this.icon,
    required this.gradient,
    required this.size,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.46),
      ),
    );
  }
}
