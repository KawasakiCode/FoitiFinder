//The app bar the three main pages share.
//
//IT EXISTS BECAUSE THEY WERE THREE COPIES OF THE SAME THING - same title, same
//padding, same titleSpacing, each written out again, and the bell would have
//been a fourth copy. The bar is identical on every tab on purpose: the tabs
//change what is under it, not the frame around it.
//
//THE BADGE COUNTS, IT DOES NOT JUST GLOW. A dot says "something happened"; a
//number says whether it is worth opening now, and the bell is the only route
//to a match waiting on an answer.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/main_pages/notifications_page.dart';
import 'package:foitifinder/providers/notifications_provider.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:provider/provider.dart';

//past this it is "lots", and three digits do not fit a bell
const int kBadgeMax = 9;

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  //home is the first tab and has nothing to go back to; the others are reached
  //by swiping, so the same applies - this stays false unless a caller is
  //pushing a main page onto a stack
  final bool showBack;

  const MainAppBar({super.key, required this.title, this.showBack = false});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    //THE BELL IS THE ONLY THING THIS ADDS over the bar every other page wears.
    //It used to build its own AppBar with titleSpacing 2 and a 10px padding
    //inside the title - twelve points in two numbers, where every pushed page
    //sat at the default sixteen. So a tab's title and a sub-page's title began
    //at different places, and walking from one to the other nudged the heading
    //sideways. Going through PageAppBar is what stops that.
    return PageAppBar(
      title: title,
      titleWidget: AppBarWordmark(label: title),
      showBack: showBack,
      actions: const [NotificationsBell(), SizedBox(width: 4)],
    );
  }
}

//THE APP'S NAME AS A PICTURE, where the three main tabs used to set it in
//Inter. Every pushed page still uses text, because those titles are words
//rather than a mark - this is the brand, and it is the same artwork the login
//screen and the policy site draw.
//
//TWO FILES, PICKED BY THEME. The ink is near-black in one and near-white in
//the other; a single image would vanish against one of the two app bars. They
//are named for the background they sit on, not for the colour they are.
class AppBarWordmark extends StatelessWidget {
  const AppBarWordmark({super.key, required this.label});

  //what a screen reader says, since an image has no words in it
  final String label;

  //SIZED BY ITS INK AND NOT BY ITS BOX, which are different numbers here.
  //
  //The file carries 18% padding above and below the lettering, so most of its
  //height is empty. Setting the image height to 20 to match the theme's
  //appBarTheme fontSize - the obvious move - draws the word 6% smaller than
  //the text it replaced, because a font size is not an ink height.
  //
  //Measured instead: Inter at w700 and size 20 puts down 15.67px of ink for
  //this string, and the image reaches that at a height of 21.36.
  //
  //MEASURE INK AT HALF COVERAGE, not at "any pixel that is not empty". Both
  //the text and the resized image carry a soft antialiased edge, and counting
  //it reverses the answer - by that rule this image looks 3% TALLER than the
  //text rather than 3% shorter, and the correction goes the wrong way.
  //
  //If the padding in make_icon.py or the title size in app_theme.dart
  //changes, this is wrong and has to be measured again.
  static const double _inkMatchedHeight = 21.36;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      dark
          ? 'assets/brand/wordmark_on_dark.png'
          : 'assets/brand/wordmark_on_light.png',
      height: _inkMatchedHeight,
      //the source is far larger than this draws it, so the downscale is what
      //decides whether the logo looks crisp or furry
      filterQuality: FilterQuality.medium,
      semanticLabel: label,
    );
  }
}

//The bell itself, kept separate so a page with its own app bar can still use
//it without taking the whole bar.
class NotificationsBell extends StatelessWidget {
  const NotificationsBell({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    //listen: the count has to change under the user when a push arrives while
    //they are looking at it
    final unread = context.watch<NotificationsProvider>().unreadCount;

    return IconButton(
      tooltip: text.notifications,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsPage()),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(unread > 0 ? Icons.notifications : Icons.notifications_none),
          if (unread > 0)
            Positioned(
              //sits on the bell's shoulder, outside its box
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  unread > kBadgeMax ? '$kBadgeMax+' : '$unread',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onError,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
