//Languages spoken: checkboxes over constants/languages.dart.
//
//This one is not decoration - it is a FILTER, and the intro line says so
//before anything is ticked. Somebody who leaves it empty is saying nothing
//about themselves; somebody who ticks only Greek is narrowing who they see.
//
//Stores canonical English strings (users.languages_spoken), translated for
//display through catalogueLabel - so a Greek user ticking «Αγγλικά» and an
//English user ticking "English" store the same value and match each other.
//
//Pops with the picked list, or null if the user backed out.

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/languages.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/widgets/primary_button.dart';

class LanguagesPage extends StatefulWidget {
  final List<String> initialSelected;
  //The line above the list. Two callers, two meanings: on the profile side it
  //is "languages I speak", in date preferences it is "languages they must
  //speak". Same list, same storage shape, so the same page - only the sentence
  //at the top changes. Defaults to the profile wording.
  final String? intro;

  const LanguagesPage({
    super.key,
    this.initialSelected = const [],
    this.intro,
  });

  @override
  State<LanguagesPage> createState() => _LanguagesPageState();
}

class _LanguagesPageState extends State<LanguagesPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    //copied, not aliased: backing out must leave the caller's list untouched
    _selected = {...widget.initialSelected};
  }

  void _toggle(String language) {
    setState(() {
      if (!_selected.remove(language)) _selected.add(language);
    });
  }

  //catalogue order, not tap order, so the saved list is stable and two users
  //with the same languages store them identically
  List<String> get _result =>
      kLanguages.where(_selected.contains).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(text.languagesSpoken),
        automaticallyImplyLeading: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            widget.intro ?? text.languagesIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final language in kLanguages)
            CheckboxListTile(
              value: _selected.contains(language),
              title: Text(catalogueLabel(text, language)),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (_) => _toggle(language),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: PrimaryButton(
          label: text.save,
          onPressed: () => Navigator.pop(context, _result),
        ),
      ),
    );
  }
}
