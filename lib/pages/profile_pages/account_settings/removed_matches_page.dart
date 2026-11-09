//Matches you removed: names only, with one thing you can do about them.
//
//WHY THIS PAGE EXISTS. Reporting somebody starts from their profile, and the
//only profiles reachable for someone you have matched with are the ones on
//the matches page. So removing a match - what a person does when they want
//somebody out of their sight - also ended their ability to report that person,
//at exactly the point where the handle is already out and misuse becomes
//possible. The server never deleted the row and the report always would have
//landed; this is the screen that was missing.
//
//NAMES AND NOTHING ELSE, which is the whole design. No photos, no ages, no
//tap-through to a profile. A removed match is somebody the user chose to stop
//seeing, so a page that gives the faces back would be an un-remove nobody
//asked for - and a profile reachable from here would make removal mean less
//than it says. A name is the least that still lets you pick the right person.
//
//NOT ON THE MATCHES PAGE, for the same reason. Putting removed matches back
//into the list they were removed from would undo the only thing removing one
//does. This lives in account settings, where somebody goes looking for it.
//
//NOT A COUNT OF ANYTHING ELSE. The list holds only matches where both sides
//confirmed - the server decides that - so it never names somebody from the
//deck who was reported without a match, and never reveals that the other
//person removed their own copy.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/matches_model.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/nav_row.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:foitifinder/widgets/report_sheet.dart';

class RemovedMatchesPage extends StatefulWidget {
  const RemovedMatchesPage({super.key});

  @override
  State<RemovedMatchesPage> createState() => _RemovedMatchesPageState();
}

class _RemovedMatchesPageState extends State<RemovedMatchesPage> {
  List<RemovedMatch> _removed = [];
  //true until the first load finishes, so the page does not flash its empty
  //state at somebody who does have removed matches
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final removed = await ApiService.getRemovedMatches();
      if (!mounted) return;
      setState(() {
        _removed = removed;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      //A FAILURE SAYS SO AND OFFERS A RETRY, rather than showing the empty
      //state. On this page the empty state means "nobody can be reported from
      //here", and telling somebody that when the request merely timed out is
      //the one wrong answer this screen can give.
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  //ALWAYS afterMatch: true. Every row here is a match both sides confirmed, so
  //the harassment group - what somebody did once they had the handle - is
  //exactly the group these reports belong to. The endpoint agrees: it finds
  //the match whether or not either side has hidden their copy.
  //
  //NOTHING IS REMOVED FROM THE LIST AFTERWARDS. The sheet shows its own
  //confirmation, and the person stays reportable: a second incident deserves
  //a second report.
  void _report(RemovedMatch match) {
    showReportSheet(
      context,
      reportedUserId: match.otherUserId,
      afterMatch: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;

    return GlassScaffold(
      appBar: AppBar(title: Text(text.removedMatchesTitle)),
      body: Crossfade(
        child: _loading
            ? const _RemovedSkeleton(key: ValueKey('loading'))
            : CustomScrollView(
                key: const ValueKey('content'),
                slivers: [
                  const SliverGlassBarInset(),
                  SliverStagger(
                    padding: const EdgeInsets.only(top: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          text.removedMatchesExplainer,
                          style: mutedText(context),
                        ),
                      ),
                      if (!_failed && _removed.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        CardGroup(
                          dividers: true,
                          children: [
                            for (final match in _removed)
                              _RemovedRow(
                                name: match.otherUserName,
                                onReport: () => _report(match),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                  if (_failed)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.cloud_off_outlined,
                        message: text.errorOccured,
                        actionLabel: text.retry,
                        onAction: _load,
                      ),
                    )
                  else if (_removed.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.person_off_outlined,
                        message: text.removedMatchesEmpty,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

//One row: a name, and the only action there is.
//
//NOT A NavRow. A NavRow has a chevron and a whole-row tap target, both of
//which promise a page behind it - and there is deliberately no page behind a
//removed match. The report button is the only thing here that does anything,
//so it is the only thing that looks tappable.
class _RemovedRow extends StatelessWidget {
  final String name;
  final VoidCallback onReport;

  const _RemovedRow({required this.name, required this.onReport});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SpringPress(
            child: TextButton.icon(
              onPressed: onReport,
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: Text(text.reportUser),
            ),
          ),
        ],
      ),
    );
  }
}

//The explainer line and a few rows, before the list has loaded.
class _RemovedSkeleton extends StatelessWidget {
  const _RemovedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          const SliverGlassBarInset(),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Bone(height: 16),
                  const SizedBox(height: 8),
                  const Bone(width: 160, height: 16),
                  const SizedBox(height: 24),
                  for (var i = 0; i < 4; i++)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Bone(width: 96, height: 16),
                          Bone(width: 96, height: 16),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
