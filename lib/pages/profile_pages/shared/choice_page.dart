//One page for every simple pick-from-a-list category: alcohol, smoking,
//dating intention, kids, religion, political view, gender identity, sexual
//orientation and pronouns.
//
//They are all the same interaction with a different list, so they share this
//page instead of getting nine near-identical files. Which list, and whether
//one answer or many, comes from the ProfileChoice passed in.
//
//Selection is handed in and handed back: the page owns no persistence. Pops
//with a List<String> - single-choice categories pop a list of length 0 or 1,
//which keeps the caller's storage uniform. Popping with the back button
//returns the same list, so nothing is lost by not tapping Save.

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/widgets/primary_button.dart';

class ChoicePage extends StatefulWidget {
  final ProfileChoice choice;
  //what was picked last time. Empty on a first visit.
  final List<String> initialSelected;

  const ChoicePage({
    super.key,
    required this.choice,
    this.initialSelected = const [],
  });

  @override
  State<ChoicePage> createState() => _ChoicePageState();
}

class _ChoicePageState extends State<ChoicePage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  late final List<String> _selected;

  @override
  void initState() {
    super.initState();
    //copy, don't alias: the caller's list must not mutate while the user is
    //still deciding, or backing out would keep the edits anyway
    _selected = List<String>.from(widget.initialSelected);
  }

  bool _isSelected(String option) => _selected.contains(option);

  //checkbox: free toggle, any number including none
  void _toggle(String option) {
    setState(() {
      if (!_selected.remove(option)) _selected.add(option);
    });
  }

  //radio: exactly one. Clearing an answer is done with the Clear action in the
  //app bar, because re-tapping a selected radio is not a gesture users expect
  //to undo anything.
  void _select(String? option) {
    setState(() {
      _selected.clear();
      if (option != null) _selected.add(option);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final choice = widget.choice;
    final isSingle = choice.mode == ChoiceMode.single;

    return PopScope(
      //the back button must return the picks too, otherwise leaving without
      //tapping Save silently throws the answer away
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, List<String>.unmodifiable(_selected));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(catalogueLabel(text, choice.title)),
          automaticallyImplyLeading: true,
          actions: [
            //the only way to go back to "no answer" on a radio list
            if (isSingle && _selected.isNotEmpty)
              TextButton(
                onPressed: () => _select(null),
                child: Text(text.clear),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(catalogueLabel(text, choice.subtitle),
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            //a radio group for one-answer categories and checkboxes for the
            //rest, so the control itself tells the user which they are dealing
            //with before they tap anything
            if (isSingle)
              RadioGroup<String>(
                groupValue: _selected.isEmpty ? null : _selected.first,
                onChanged: _select,
                child: Column(
                  children: [
                    for (final option in choice.options)
                      RadioListTile<String>(
                        value: option,
                        title: Text(catalogueLabel(text, option)),
                        contentPadding: EdgeInsets.zero,
                        //the same tightening as choice_dialog.dart: these are
                        //answers to one question, not unrelated settings
                        dense: true,
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                      ),
                  ],
                ),
              )
            else
              for (final option in choice.options)
                CheckboxListTile(
                  value: _isSelected(option),
                  title: Text(catalogueLabel(text, option)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (_) => _toggle(option),
                ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: PrimaryButton(
            label: text.save,
            onPressed: () => Navigator.pop(
              context,
              List<String>.unmodifiable(_selected),
            ),
          ),
        ),
      ),
    );
  }
}
