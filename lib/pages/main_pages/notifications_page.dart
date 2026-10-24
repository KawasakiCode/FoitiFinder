//The bell's list: things that happened, newest first.
//
//NOTHING WRITES A MATCH NOTIFICATION ANY MORE. Matches moved to their own
//page, which is always reachable and always current, so a stored row about
//one could only ever be a staler copy of a screen the user can just open -
//and it was that row which made 'match' mean two different things at once,
//gave the wrong title to whoever completed the match, and sat dead in the
//bell the moment they answered. A match is a push and a list entry now.
//
//THE PAGE AND ITS KINDS ARE KEPT ON PURPOSE, for the report flow: telling
//somebody what came of a report they filed, or that one was filed about them,
//is exactly the kind of thing with nowhere else to live. The match kinds
//below still render correctly if anything ever writes one again. Today
//nothing does, so the bell is empty until reports land.
//
//A TAP GOES STRAIGHT THERE. There is no notification detail screen, because
//there is nothing a detail screen could add - the two lines here already say
//what happened and what it wants, and a match page one tap away is the whole
//point. A screen whose only content is "open the thing you just tapped" is a
//tax on every single notification.
//
//READ IS DIMMED, NOT HIDDEN. A revealed Instagram is the one thing in this app
//a user may come back for days later, so nothing is ever removed from this
//list for having been seen once; it just stops shouting.
//
//THE WORDING LIVES HERE, not in the payload. The server sends a kind and who
//it is about; this file turns that into a sentence, so it is translated like
//everything else and an old build never shows a string written by a newer
//server.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/notification_model.dart';
import 'package:foitifinder/pages/main_pages/match_page.dart';
import 'package:foitifinder/providers/notifications_provider.dart';
import 'package:foitifinder/widgets/profile_photo.dart';
import 'package:provider/provider.dart';

//enough that a read row is clearly behind the others, not so little that it
//becomes unreadable
const double _kReadOpacity = 0.45;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    //refresh on open: a push may have arrived while the app was closed, and
    //this page is the one place the user is explicitly asking "what happened?"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsProvider>().load();
    });
  }

  Future<void> _open(AppNotification note) async {
    final provider = context.read<NotificationsProvider>();
    //dims immediately, request behind it
    await provider.markRead(note);

    if (!note.canOpen || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchPage(
          matchId: note.matchId!,
          otherUserId: note.otherUserId!,
          otherName: note.otherName ?? text.notifSomeone,
          otherPhotoUrl: note.otherPhotoUrl,
          //ARRIVED FROM A NOTIFICATION, so this is not the person who just
          //swiped: they are answering a match made a while ago, and they are
          //allowed to leave without answering. A reveal opens straight to the
          //handle instead of asking again.
          fromNotification: true,
          openRevealed: note.kind == NotificationKind.matchRevealed,
          //only say "they said yes" when they actually have: this same kind
          //also reaches the person who completed the match, whose turn it is
          //while the other side has not answered at all
          theyConfirmed: note.otherConfirmed,
        ),
      ),
    );

    //the match may now be confirmed, revealed or gone
    if (mounted) await provider.load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(text.notifications),
        automaticallyImplyLeading: true,
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: items.isEmpty
            ? _EmptyList(
                message: text.noNotifications,
                loading: provider.isLoading,
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final note = items[index];
                  return _NotificationRow(
                    note: note,
                    onTap: () => _open(note),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  final String message;
  final bool loading;

  const _EmptyList({required this.message, required this.loading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    //still a scroll view, or there is nothing to pull on - and an empty bell
    //is exactly when someone pulls to refresh
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification note;
  final VoidCallback onTap;

  const _NotificationRow({required this.note, required this.onTap});

  //Two lines: what happened, and what it wants. Written here rather than sent
  //by the server - see the note at the top of the file.
  (String, String) _lines(AppLocalizations text) {
    final name = note.otherName ?? text.notifSomeone;
    return switch (note.kind) {
      //BOTH SIDES OF A MATCH GET THIS KIND, and the two of them did opposite
      //things. One was liked and is being told about it; the other did the
      //liking and completed the match themselves, and is only here because
      //the bell is the way back to a match page they may have left. So the
      //title has to turn around too - "Maria matched with you" is backwards
      //for the person who tapped like, and otherConfirmed is what tells them
      //apart.
      NotificationKind.matchWaiting => (
        note.otherConfirmed
            ? text.notifMatchWaitingTitle(name)
            : text.notifMatchOwnTitle(name),
        note.otherConfirmed
            ? text.notifMatchWaitingBody
            : text.notifMatchOwnBody,
      ),
      NotificationKind.matchRevealed => (
        text.notifMatchRevealedTitle(name),
        text.notifMatchRevealedBody,
      ),
      NotificationKind.matchDeclined => (
        text.notifMatchDeclinedTitle(name),
        text.notifMatchDeclinedBody,
      ),
      //written by a newer backend: say who it was about and nothing more,
      //rather than dropping the row and leaving a gap in the list
      NotificationKind.unknown => (name, ''),
    };
  }

  String _age(AppLocalizations text) {
    final elapsed = DateTime.now().difference(note.createdAt);
    if (elapsed.inMinutes < 1) return text.notifJustNow;
    if (elapsed.inHours < 1) return text.notifMinutesAgo(elapsed.inMinutes);
    if (elapsed.inDays < 1) return text.notifHoursAgo(elapsed.inHours);
    return text.notifDaysAgo(elapsed.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final (title, body) = _lines(text);

    return Opacity(
      opacity: note.read ? _kReadOpacity : 1,
      child: ListTile(
        //SPENT NOTIFICATIONS ARE NOT TAPPABLE. A match already answered, a
        //declined one, an account that is gone - all of them lead nowhere, so
        //the row stops behaving like a link. An unread one still takes a tap,
        //because that is how it gets marked read.
        onTap: note.canOpen || !note.read ? onTap : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          width: 52,
          height: 52,
          child: ClipOval(
            child: PersonPhoto(
              url: note.otherPhotoUrl,
              decodeWidth: kThumbDecodeWidth,
              missingIconSize: 26,
            ),
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            //unread reads as the thing to look at; read is just history
            fontWeight: note.read ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: Text(
          _age(text),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
