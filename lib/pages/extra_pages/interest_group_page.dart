//Shows ONE group of the interest catalogue (Hobbies & interests, or Traits)
//with all of its sections underneath.
//
//Reached from the category list on the profile page. Each group gets its own
//page so the shared budget shown in the app bar ("7/10") always refers to the
//one thing the user is looking at.
//
//Selection is handed in and handed back: the page owns no persistence. The
//caller passes what was picked last time and receives the new picks on pop, so
//wiring this to the backend later is a change in ONE place (the caller), not in
//here.
//
//Pops with a Map<String, List<String>> keyed by section title. Popping with the
//back button returns the same map, so nothing is lost by not tapping Save.

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/interest_catalogue.dart';
import 'package:foitifinder/widgets/interest_box.dart';
import 'package:foitifinder/widgets/primary_button.dart';

class InterestGroupPage extends StatefulWidget {
  final InterestGroup group;
  //what was picked last time, keyed by section title. Empty on a first visit.
  final Map<String, List<String>> initialSelections;

  const InterestGroupPage({
    super.key,
    required this.group,
    this.initialSelections = const {},
  });

  @override
  State<InterestGroupPage> createState() => _InterestGroupPageState();
}

class _InterestGroupPageState extends State<InterestGroupPage> {
  //section title -> the options picked in it, in tap order (order matters if we
  //ever show only the first few on a profile card)
  late final Map<String, List<String>> _selected;

  @override
  void initState() {
    super.initState();
    //copy the lists, don't alias them: the caller's map must not mutate while
    //the user is still deciding, or backing out would keep the edits anyway
    _selected = {
      for (final entry in widget.initialSelections.entries)
        entry.key: List<String>.from(entry.value),
    };
  }

  //read-only: never creates the entry, so calling it from build() can't mutate
  //state. _toggle is the only thing that writes.
  List<String> picksIn(InterestSection section) =>
      _selected[section.title] ?? const [];

  //every pick in the group, across all its sections - this is what the shared
  //budget is measured against
  int get groupCount => widget.group.sections.fold(
        0,
        (sum, section) => sum + picksIn(section).length,
      );

  bool isSelected(InterestSection section, String option) =>
      picksIn(section).contains(option);

  //whether a *new* pick would be refused. A single-pick section that already
  //has its pick is never full - tapping another box swaps the choice, which
  //costs nothing against either budget.
  bool isFull(InterestSection section) {
    final picks = picksIn(section);
    if (section.maxSelections == 1 && picks.isNotEmpty) return false;
    //the tighter of the two limits wins
    if (section.maxSelections != null && picks.length >= section.maxSelections!) {
      return true;
    }
    final shared = widget.group.sharedMax;
    return shared != null && groupCount >= shared;
  }

  void _toggle(InterestSection section, String option) {
    setState(() {
      final picks = _selected.putIfAbsent(section.title, () => []);

      //tapping something already picked always removes it, even when full
      if (picks.remove(option)) return;

      //radio sections (star sign, MBTI): swapping the existing pick keeps the
      //count identical, so it runs before the budget checks and can never be
      //blocked by a full group. Taking the FIRST pick still has to pay for it.
      if (section.maxSelections == 1 && picks.isNotEmpty) {
        picks
          ..clear()
          ..add(option);
        return;
      }

      //a pick has to clear its own section cap and the group's shared budget
      if (section.maxSelections != null &&
          picks.length >= section.maxSelections!) {
        return;
      }
      final shared = widget.group.sharedMax;
      if (shared != null && groupCount >= shared) return;

      picks.add(option);
    });
  }

  //the picks, with empty sections dropped so the caller never stores noise
  Map<String, List<String>> get _result => {
        for (final entry in _selected.entries)
          if (entry.value.isNotEmpty)
            entry.key: List<String>.unmodifiable(entry.value),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shared = widget.group.sharedMax;

    return PopScope(
      //the back button must return the picks too, otherwise leaving without
      //tapping Save silently throws the edits away
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _result);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.group.title),
          automaticallyImplyLeading: true,
          actions: [
            //the shared budget lives in the app bar: it belongs to the group as
            //a whole, and no single section owns it
            if (shared != null)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Center(
                  child: Text(
                    '$groupCount/$shared',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
          ],
        ),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: widget.group.sections.length,
          separatorBuilder: (_, _) => const SizedBox(height: 28),
          itemBuilder: (context, index) => _SectionBlock(
            section: widget.group.sections[index],
            state: this,
          ),
        ),
        //save bar sits outside the list so it never covers the last section
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: PrimaryButton(
            label: groupCount == 0 ? 'Save' : 'Save $groupCount selected',
            onPressed: () => Navigator.pop(context, _result),
          ),
        ),
      ),
    );
  }
}

//A section title with its counter (only when the section owns its own cap) and
//the boxes underneath.
class _SectionBlock extends StatelessWidget {
  final InterestSection section;
  final _InterestGroupPageState state;

  const _SectionBlock({required this.section, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
              ),
            ),
            //only drawn when the section really owns a cap - a per-section
            //"2/3" would be a lie for sections that just draw on the group
            //budget, which is shown in the app bar instead
            if (section.maxSelections != null)
              Text(
                '${state.picksIn(section).length}/${section.maxSelections}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in section.options)
              InterestBox(
                label: option,
                selected: state.isSelected(section, option),
                //greyed out once there's no room left, but still tappable to
                //deselect if it's one of the picked ones
                dimmed: state.isFull(section) &&
                    !state.isSelected(section, option),
                onTap: () => state._toggle(section, option),
              ),
          ],
        ),
      ],
    );
  }
}
