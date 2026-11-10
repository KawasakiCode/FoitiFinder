//The bell's list: things that happened, newest first.
//
//NOTHING WRITES A MATCH NOTIFICATION. Matches have their own page, which is
//always reachable and always current, so a stored row about one could only
//ever be a staler copy of a screen the user can simply open - and it would
//make 'match' mean two different things at once. A match is a push and a
//list entry.
//
//THE PAGE AND ITS KINDS ARE KEPT ON PURPOSE, for the report flow: telling
//somebody what came of a report they filed, or that one was filed about
//them, is exactly the kind of thing with nowhere else to live. The match
//kinds below still render correctly if anything ever writes one, so the bell
//is empty until reports land.
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
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/polish.dart';
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

  //rows that have already played their entrance; see Entrance.shouldPlay
  final Set<int> _enteredRows = {};

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
      //the list scrolls under the frosted bar
      extendBodyBehindAppBar: true,
      //GlassAppBar by hand rather than GlassScaffold, because the body is a
      //RefreshIndicator that needs the bar's height for its edgeOffset
      appBar: GlassAppBar(child: PageAppBar(title: text.notifications)),
      body: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
        onRefresh: provider.load,
        child: Crossfade(
          child: items.isEmpty
              ? _EmptyList(
                  key: ValueKey(provider.isLoading ? 'loading' : 'empty'),
                  message: text.noNotifications,
                  actionLabel: text.retry,
                  onAction: provider.load,
                  loading: provider.isLoading,
                )
              : CustomScrollView(
                  key: const ValueKey('list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    const SliverGlassBarInset(),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final note = items[index];
                          return Entrance(
                            key: ValueKey(note.id),
                            order: Entrance.orderFor(index),
                            shouldPlay: () => _enteredRows.add(note.id),
                            child: _NotificationRow(
                              note: note,
                              onTap: () => _open(note),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final bool loading;

  const _EmptyList({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    //still a scroll view, or there is nothing to pull on - and an empty bell
    //is exactly when someone pulls to refresh
    final Widget scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverGlassBarInset(),
        if (loading)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverToBoxAdapter(child: _RowSkeletons()),
          )
        else
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.notifications_none,
              message: message,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
          ),
      ],
    );

    return loading ? Shimmer(child: scroll) : scroll;
  }
}

//The shape of a few rows: a face, two lines, and the time at the end.
class _RowSkeletons extends StatelessWidget {
  const _RowSkeletons();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 6; i++)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Bone(width: 48, height: 48, circle: true),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone(width: 160, height: 16),
                      SizedBox(height: 8),
                      Bone(height: 8),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Bone(width: 24, height: 8),
              ],
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
    final Color muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final VoidCallback? rowTap = note.canOpen || !note.read ? onTap : null;

    //dims when it is read rather than snapping; no begin, so a row that is
    //already read simply starts dim
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: note.read ? _kReadOpacity : 1),
      duration: AppMotion.base,
      curve: AppMotion.standard,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: SpringPress(
        enabled: rowTap != null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.card,
          ),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              //SPENT NOTIFICATIONS ARE NOT TAPPABLE. A match already answered,
              //a declined one, an account that is gone - all of them lead
              //nowhere, so the row stops behaving like a link. An unread one
              //still takes a tap, because that is how it gets marked read.
              onTap: rowTap,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: SizedBox(
                width: 48,
                height: 48,
                child: ClipOval(
                  child: PersonPhoto(
                    url: note.otherPhotoUrl,
                    decodeWidth: kThumbDecodeWidth,
                    missingIconSize: 24,
                  ),
                ),
              ),
              title: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  //unread reads as the thing to look at; read is just history
                  fontWeight: note.read ? FontWeight.w500 : FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
              trailing: Text(
                _age(text),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
