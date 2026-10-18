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
    return AppBar(
      titleSpacing: 2,
      automaticallyImplyLeading: showBack,
      title: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Text(title),
      ),
      actions: const [NotificationsBell(), SizedBox(width: 4)],
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
