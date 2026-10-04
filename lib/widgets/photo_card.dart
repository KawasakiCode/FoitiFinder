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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/models/card_data_model.dart';
import 'package:foitifinder/theme/app_colors.dart';

//how round the card is; the deck and the photo clip share it
const double kCardRadius = 24;

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

class PhotoCard extends StatefulWidget {
  final CardData card;
  //Ties this card's photo to the header photo of the profile page, so opening
  //a profile grows the photo out of the card instead of sliding a new screen
  //over it. Null on the cards behind: only the top one is ever opened, and two
  //Heroes sharing a tag is a crash.
  final Object? photoHeroTag;
  //null on the cards stacked behind: only the top card acts
  final VoidCallback? onOpen;
  final VoidCallback? onPass;
  final VoidCallback? onSuperLike;
  final VoidCallback? onLike;

  const PhotoCard({
    super.key,
    required this.card,
    this.photoHeroTag,
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

  //Only the top card flies; the ones behind are drawn plainly.
  Widget _maybeHero(Widget child) => widget.photoHeroTag == null
      ? child
      : Hero(
          tag: widget.photoHeroTag!,
          flightShuttleBuilder: photoHeroFlightShuttle,
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
          //first layer: the photo AND the top scrim, together, because both
          //have to survive the flight to the profile page
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
              ],
            ),
          ),

          //second layer: the bottom half of the darkening, which belongs to
          //this card alone - the profile page puts its controls elsewhere
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.5, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
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

          //fifth layer: the stats, then the actions
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _StatSlots(),
                const SizedBox(height: 14),
                _CardActions(
                  onPass: widget.onPass,
                  onSuperLike: widget.onSuperLike,
                  onLike: widget.onLike,
                ),
              ],
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
