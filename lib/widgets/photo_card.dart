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

class PhotoCard extends StatefulWidget {
  final CardData card;
  //null on the cards stacked behind: only the top card acts
  final VoidCallback? onOpen;
  final VoidCallback? onPass;
  final VoidCallback? onSuperLike;
  final VoidCallback? onLike;

  const PhotoCard({
    super.key,
    required this.card,
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
          //first layer is the photo itself
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
            errorWidget: (context, url, error) => Container(color: Colors.grey),
          ),

          //second layer: dark at BOTH ends now, because the card has text at
          //the top and controls at the bottom
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.28, 0.5, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
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
