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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(text.removedMatchesTitle)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(top: 15, bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Text(
                      text.removedMatchesExplainer,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_failed)
                    _Message(
                      text: text.errorOccured,
                      action: text.retry,
                      onAction: _load,
                    )
                  else if (_removed.isEmpty)
                    _Message(text: text.removedMatchesEmpty)
                  else
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
      padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: onReport,
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text(text.reportUser),
          ),
        ],
      ),
    );
  }
}

//The empty and failed states, which differ only in whether there is anything
//to press.
class _Message extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const _Message({required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
