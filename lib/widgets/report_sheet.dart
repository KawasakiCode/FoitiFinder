//Reporting a profile: three steps in one sheet.
//
//ONE SHEET, NOT THREE ROUTES. Each step covers the last completely and they
//are all the same height, so nothing is gained by stacking modal routes - and
//a single route gets two of the required behaviours for free: tapping the
//space above closes the whole flow, and so does the X, because both are just
//this one route being popped. Three routes would need the barrier tap to pop
//all of them, which is the kind of thing that works until somebody adds a
//fourth step.
//
//WHAT THE STEPS ARE:
//    categories     what kind of thing happened
//    subcategories  which one, titled for the category it came from
//    details        a text box, and the only part a human will read closely
//
//THE SYSTEM BACK GOES BACK ONE STEP, not out. On a sheet that is three deep,
//a back gesture that threw away two answers would be a trap - so PopScope
//intercepts it and only the first step lets it through.
//
//'NOT INTERESTED' IS IN HERE AND IS NOT A REPORT. It is the pressure valve:
//without it, somebody who simply dislikes a profile has nothing to press but
//an accusation, and the queue fills with reports that are really passes. It
//records a pass, which is what the deck would have done anyway.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/primary_button.dart';

//HOW MUCH OF THE SCREEN. Tall enough that the options do not scroll on a
//phone, short enough that the profile behind it is still visible - this is a
//thing you do ABOUT something, and seeing it helps.
const double kReportSheetHeight = 0.8;

//THE CODES, MIRRORING backend/report_reasons.py. The server validates the
//pair, so a code invented here is refused rather than filed - but it would be
//refused at the worst moment, after somebody typed out what happened. These
//are kept in the same order as that file so the two can be read side by side.
//
//THE WORDS ARE NOT HERE. They are in the .arb files, because a sentence built
//where the validation lives is a sentence that cannot be translated - which
//is how the push notifications ended up English-only in a bilingual app.
const Map<String, List<String>> kReportReasons = {
  'profile_content': [
    'nudity_or_sexual',
    'hateful_violent_disturbing',
    'other',
  ],
  'underage': [
    'may_be_under_18',
    'minor_sexual_content',
    'other',
  ],
  'fake_profile': [
    'not_the_person_in_the_photos',
    'impersonation',
    'spam_scam_or_money',
    'other',
  ],
  'harassment': [
    'abusive_messages',
    'threats_or_stalking',
    'sexual_assault',
    'shared_my_information',
    'made_me_feel_unsafe',
    'other',
  ],
};

//ONLY AFTER A MATCH. Harassment here means what somebody did once they had
//your Instagram handle, which cannot be true of a stranger in the deck. The
//endpoint refuses it too; hiding it is what stops anybody reaching for the
//worst-sounding option because the real one was not listed.
const String kAfterMatchOnlyCategory = 'harassment';

/// Open the report flow for [reportedUserId].
///
/// [afterMatch] decides whether the harassment group is offered at all.
/// [onReported] runs once a report has been filed - the profile behind this
/// sheet usually has to close, since the person has just left the deck.
Future<void> showReportSheet(
  BuildContext context, {
  required int reportedUserId,
  required bool afterMatch,
  VoidCallback? onReported,
  VoidCallback? onNotInterested,
}) {
  return showModalBottomSheet<void>(
    context: context,
    //so the sheet can be a fixed fraction of the screen rather than being
    //capped at half of it
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    //THE EMPTY SPACE ABOVE IS OURS, NOT THE ROUTE'S, and that is not a
    //preference. A barrier tap dismisses through the same maybePop that the
    //system back uses, so PopScope cannot tell them apart - and the two have
    //to differ: back goes one step, tapping outside closes the lot. So the
    //route's barrier is turned off and the sheet draws its own.
    isDismissible: false,
    //for the same reason: a drag-to-dismiss would arrive as a pop and be
    //intercepted into a step backwards, which is not what dragging means
    enableDrag: false,
    builder: (_) => _ReportSheet(
      reportedUserId: reportedUserId,
      afterMatch: afterMatch,
      onReported: onReported,
      onNotInterested: onNotInterested,
    ),
  );
}

enum _Step { categories, subcategories, details }

class _ReportSheet extends StatefulWidget {
  final int reportedUserId;
  final bool afterMatch;
  final VoidCallback? onReported;
  final VoidCallback? onNotInterested;

  const _ReportSheet({
    required this.reportedUserId,
    required this.afterMatch,
    this.onReported,
    this.onNotInterested,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet>
    with SingleTickerProviderStateMixin {
  _Step _step = _Step.categories;
  String? _category;
  String? _subcategory;
  //which way the next transition should travel, so going back does not look
  //like going forward
  bool _forward = true;
  bool _busy = false;

  //A PAGE PUSH, DRIVEN BY HAND, and the reason is what it replaced.
  //
  //AnimatedSwitcher CROSS-FADES: it hands the same transition builder to the
  //outgoing child with a reversing animation, so that child retraced its
  //entrance - sliding back out the way it had come in while the new one
  //arrived from the same side. Two panels of text moving through each other
  //in opposite directions, which is exactly what it looked like.
  //
  //A push moves both panels the SAME way: the one you are leaving slides out
  //to the left while the new one comes in from the right. That needs the
  //outgoing panel kept alive and animated independently, which no single
  //built-in switcher does.
  //STARTS COMPLETED, which is not a detail. The tweens map 0 to "entering
  //from the side" and 1 to "in place", so a controller left at 0 would hold
  //the very first panel translated a full width off screen - drawn, laid out,
  //and untappable, with nothing on screen to say why.
  late final AnimationController _slide = AnimationController(
    duration: const Duration(milliseconds: 260),
    value: 1,
    vsync: this,
  );
  //the panel being left behind, held only for the length of the animation
  Widget? _leaving;

  final TextEditingController _details = TextEditingController();

  AppLocalizations get text => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _slide.dispose();
    _details.dispose();
    super.dispose();
  }

  List<String> get _categories => [
        for (final category in kReportReasons.keys)
          if (widget.afterMatch || category != kAfterMatchOnlyCategory)
            category,
      ];

  void _goTo(_Step step, {bool forward = true}) {
    //BUILT BEFORE THE STATE MOVES. _body reads _step, _category and
    //_subcategory, so a snapshot taken afterwards would be a second copy of
    //the panel we are travelling TO - and the animation would show the same
    //screen sliding across itself.
    final leaving = _body(Theme.of(context));
    setState(() {
      _leaving = leaving;
      _forward = forward;
      _step = step;
    });
    _slide.forward(from: 0).then((_) {
      //dropped as soon as it is off screen: it is a whole ListView, and
      //keeping it would mean two of them alive for the rest of the sheet
      if (mounted) setState(() => _leaving = null);
    });
  }

  void _back() {
    switch (_step) {
      case _Step.categories:
        Navigator.pop(context);
      case _Step.subcategories:
        _goTo(_Step.categories, forward: false);
      case _Step.details:
        _goTo(_Step.subcategories, forward: false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ApiService.sendReport(
        reportedUserId: widget.reportedUserId,
        category: _category!,
        subcategory: _subcategory!,
        details: _details.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      //THE SNACKBAR IS THE WHOLE RECEIPT. There is no screen listing reports
      //you have filed - that would be a list of accusations with no outcome
      //on it - so this line is the only confirmation there will ever be, and
      //it says the thing people actually wonder: that it went somewhere.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.reportSent)),
      );
      widget.onReported?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.errorOccured)),
      );
    }
  }

  void _notInterested() {
    Navigator.pop(context);
    widget.onNotInterested?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      //the first step is the only one where leaving means leaving
      canPop: _step == _Step.categories,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: SizedBox.expand(
        child: Stack(
          children: [
            //BEHIND THE CARD AND BEHIND NOTHING ELSE. Taps on the card never
            //reach it because the card is painted on top; taps on the space
            //above it do, and they close the whole flow however deep it is.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _busy ? null : () => Navigator.pop(context),
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: kReportSheetHeight,
                child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _header(theme),
              Expanded(child: _slidingBody(theme)),
            ],
          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //The panel, mid-push.
  //
  //CLIPPED BY THE CARD ABOVE (Clip.antiAlias on the Container), so a panel
  //sliding out does not paint across the rounded corners or past the edge.
  Widget _slidingBody(ThemeData theme) {
    final curve = CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic);
    //leftwards going forward, rightwards coming back - both panels together
    final direction = _forward ? -1.0 : 1.0;

    return Stack(
      children: [
        if (_leaving != null)
          SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: Offset(direction, 0),
            ).animate(curve),
            child: _leaving!,
          ),
        SlideTransition(
          position: Tween<Offset>(
            begin: Offset(-direction, 0),
            end: Offset.zero,
          ).animate(curve),
          child: _body(theme),
        ),
      ],
    );
  }

  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          //SPACE IS HELD EVEN WHEN THERE IS NO ARROW, so the title does not
          //shift sideways between steps.
          SizedBox(
            width: 48,
            child: _step == _Step.categories
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _busy ? null : _back,
                  ),
          ),
          Expanded(
            //A QUICK CROSS-FADE, not a slide and not a hard swap. The panel
            //below travels sideways; a title hard-cutting beside it reads as
            //a glitch, and sliding it would pull it out from between the two
            //icons it is centred against.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                _title(),
                key: ValueKey(_title()),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          //OUT FROM ANY DEPTH. Backing out step by step from the third screen
          //to abandon a report is three presses to do nothing.
          SizedBox(
            width: 48,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _busy ? null : () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  String _title() => switch (_step) {
        _Step.categories => text.reportTitle,
        //A TITLE PER CATEGORY, so the second screen says which drawer you
        //opened. 'Report profile' twice gives no sense of having moved.
        _Step.subcategories => _categoryTitle(_category!),
        _Step.details => text.reportDetailsTitle,
      };

  Widget _body(ThemeData theme) => switch (_step) {
        _Step.categories => _categoriesBody(theme),
        _Step.subcategories => _subcategoriesBody(theme),
        _Step.details => _detailsBody(theme),
      };

  Widget _categoriesBody(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _note(theme, text.reportAnonymous),
        const SizedBox(height: 8),
        for (final category in _categories)
          _row(
            label: _categoryLabel(category),
            onTap: () {
              _category = category;
              _goTo(_Step.subcategories);
            },
          ),
        //SEPARATED, because it is not one of the above. Somebody who merely
        //does not like a profile should not have to pick an accusation, and
        //this is what keeps the queue free of reports that are really passes.
        //
        //ABSENT WHERE IT WOULD BE THE WRONG QUESTION. The caller leaves the
        //callback null on a profile opened from the matches page: you cannot
        //be uninterested in somebody whose Instagram you already have, and
        //the honest version of that wish is 'Remove match', which lives in
        //the same menu and warns before it acts.
        if (widget.onNotInterested != null) ...[
          const SizedBox(height: 20),
          Divider(color: theme.dividerColor.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          _row(
            label: text.reportNotInterested,
            icon: Icons.visibility_off_outlined,
            onTap: _notInterested,
          ),
        ],
      ],
    );
  }

  Widget _subcategoriesBody(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final subcategory in kReportReasons[_category]!)
          _row(
            label: _subcategoryLabel(subcategory),
            onTap: () {
              _subcategory = subcategory;
              _goTo(_Step.details);
            },
          ),
      ],
    );
  }

  Widget _detailsBody(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _note(theme, text.reportDetailsHelp),
        const SizedBox(height: 14),
        TextField(
          controller: _details,
          maxLines: 6,
          minLines: 4,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          enabled: !_busy,
          decoration: InputDecoration(
            hintText: text.reportDetailsHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: text.reportSubmit,
          onPressed: _busy ? null : _submit,
          isLoading: _busy,
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(
            text.cancel,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _note(ThemeData theme, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: theme.hintColor, height: 1.35),
      ),
    );
  }

  Widget _row({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: _busy ? null : onTap,
          leading: icon == null ? null : Icon(icon, color: Colors.grey),
          title: Text(label, style: const TextStyle(fontSize: 15)),
          trailing: const Icon(Icons.chevron_right, size: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }

  //THE CODE-TO-WORDS MAPPING, and the reason it is a switch rather than a map
  //built once: AppLocalizations needs a context, so every label is a getter
  //call and a map would have to be rebuilt on each use anyway. A switch with
  //no default also means adding a code to kReportReasons without translating
  //it fails to compile rather than showing somebody a raw code.
  String _categoryLabel(String category) => switch (category) {
        'profile_content' => text.reportProfileContent,
        'underage' => text.reportUnderage,
        'fake_profile' => text.reportFakeProfile,
        'harassment' => text.reportHarassment,
        _ => category,
      };

  String _categoryTitle(String category) => switch (category) {
        'profile_content' => text.reportProfileContentTitle,
        'underage' => text.reportUnderageTitle,
        'fake_profile' => text.reportFakeProfileTitle,
        'harassment' => text.reportHarassmentTitle,
        _ => text.reportTitle,
      };

  String _subcategoryLabel(String subcategory) => switch (subcategory) {
        'nudity_or_sexual' => text.reportNudity,
        'hateful_violent_disturbing' => text.reportHateful,
        'may_be_under_18' => text.reportMayBeUnder18,
        'minor_sexual_content' => text.reportMinorSexualContent,
        'not_the_person_in_the_photos' => text.reportNotThePerson,
        'impersonation' => text.reportImpersonation,
        'spam_scam_or_money' => text.reportSpamScam,
        'abusive_messages' => text.reportAbusiveMessages,
        'threats_or_stalking' => text.reportThreats,
        'sexual_assault' => text.reportSexualAssault,
        'shared_my_information' => text.reportSharedMyInfo,
        'made_me_feel_unsafe' => text.reportFeltUnsafe,
        'other' => text.reportOther,
        _ => subcategory,
      };
}
