//The original all-in-one interests page: every group on a single scroll.
//
//SUPERSEDED by the per-group flow reached from the profile page
//(InterestGroupPage, one group at a time). Kept because nothing has been
//decided about removing it, but it is no longer the way in.
//
//The catalogue and the pill widget it used to declare now live in
//lib/constants/interest_catalogue.dart and lib/widgets/interest_box.dart, so
//both pages stay in step instead of drifting apart.
//
//UI ONLY: nothing here talks to a provider, the API or the user model. The
//selection lives in _selected and save() just hands it back to the caller.

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/interest_catalogue.dart';
import 'package:foitifinder/widgets/interest_box.dart';
import 'package:foitifinder/widgets/primary_button.dart';


class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key});

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  //"group/section" -> the options picked in it, in tap order (order matters if
  //we ever show only the first few on a profile card)
  final Map<String, List<String>> _selected = {};

  String _keyFor(InterestGroup group, InterestSection section) =>
      '${group.title}/${section.title}';

  //read-only: never creates the entry, so calling it from build() can't mutate
  //state. toggleInterest is the only thing that writes.
  List<String> picksIn(InterestGroup group, InterestSection section) =>
      _selected[_keyFor(group, section)] ?? const [];

  //every pick in a group, across all its sections — this is what the shared
  //budget is measured against
  int groupCount(InterestGroup group) => group.sections.fold(
        0,
        (sum, section) => sum + picksIn(group, section).length,
      );

  bool isSelected(InterestGroup group, InterestSection section, String option) =>
      picksIn(group, section).contains(option);

  //whether a *new* pick would be refused. A single-pick section that already
  //has its pick is never full — tapping another box swaps the choice, which
  //costs nothing against either budget.
  bool isFull(InterestGroup group, InterestSection section) {
    final picks = picksIn(group, section);
    if (section.maxSelections == 1 && picks.isNotEmpty) return false;
    //the tighter of the two limits wins
    if (section.maxSelections != null && picks.length >= section.maxSelections!) {
      return true;
    }
    return group.sharedMax != null && groupCount(group) >= group.sharedMax!;
  }

  void toggleInterest(
    InterestGroup group,
    InterestSection section,
    String option,
  ) {
    setState(() {
      final picks = _selected.putIfAbsent(_keyFor(group, section), () => []);

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
      if (group.sharedMax != null && groupCount(group) >= group.sharedMax!) {
        return;
      }

      picks.add(option);
    });
  }

  //every pick on the page, flattened
  List<String> get allSelected => [
        for (final group in kInterestGroups)
          for (final section in group.sections) ...picksIn(group, section),
      ];

  //TODO: persist once the backend field exists. Local-only on purpose for now.
  void save() {
    Navigator.of(context).pop({
      for (final entry in _selected.entries)
        if (entry.value.isNotEmpty) entry.key: List<String>.unmodifiable(entry.value),
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = allSelected.length;

    return Scaffold(
      appBar: AppBar(
        //TODO: move to l10n along with the catalogue labels
        title: const Text('Interests'),
        automaticallyImplyLeading: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: kInterestGroups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 36),
        itemBuilder: (context, index) =>
            _GroupBlock(group: kInterestGroups[index], state: this),
      ),
      //save bar sits outside the list so it never covers the last group
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: PrimaryButton(
          label: total == 0 ? 'Save' : 'Save $total selected',
          onPressed: save,
        ),
      ),
    );
  }
}

//One of the 5 broad blocks: its title, the shared counter if it has one, and
//every section underneath.
class _GroupBlock extends StatelessWidget {
  final InterestGroup group;
  final _InterestsPageState state;

  const _GroupBlock({required this.group, required this.state});

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
                group.title,
                style: theme.textTheme.headlineMedium?.copyWith(fontSize: 22),
              ),
            ),
            //the shared budget lives on the group header, since no single
            //section owns it
            if (group.sharedMax != null)
              Text(
                '${state.groupCount(group)}/${group.sharedMax}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
              ),
          ],
        ),
        if (group.placeholder != null) ...[
          const SizedBox(height: 8),
          Text(group.placeholder!, style: theme.textTheme.bodySmall),
        ],
        for (final section in group.sections) ...[
          const SizedBox(height: 20),
          _SectionBlock(group: group, section: section, state: state),
        ],
      ],
    );
  }
}

//A section title with its counter (only when the section owns its own cap) and
//the boxes underneath.
class _SectionBlock extends StatelessWidget {
  final InterestGroup group;
  final InterestSection section;
  final _InterestsPageState state;

  const _SectionBlock({
    required this.group,
    required this.section,
    required this.state,
  });

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
            //only drawn when the section really owns a cap — a per-section
            //"2/3" would be a lie for sections that just draw on the group
            //budget, which is shown on the group header instead
            if (section.maxSelections != null)
              Text(
                '${state.picksIn(group, section).length}/${section.maxSelections}',
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
                selected: state.isSelected(group, section, option),
                //greyed out once there's no room left, but still tappable to
                //deselect if it's one of the picked ones
                dimmed: state.isFull(group, section) &&
                    !state.isSelected(group, section, option),
                onTap: () => state.toggleInterest(group, section, option),
              ),
          ],
        ),
      ],
    );
  }
}
