//Pronouns: pick one of the three common sets, or write your own.
//
//THE TWO INPUTS ARE ONE ANSWER. Picking a radio locks the text field (dimmed
//and untouchable); writing in the text field means no radio is selected. They
//are alternatives, not a choice plus a note, so they share a single column -
//`pronouns` holds either 'she/her' or whatever the user typed. A free-text
//value simply has no entry in catalogue_labels.dart and displays as written,
//which is exactly right for someone's own wording.
//
//Clearing is the app bar's Clear action, exactly as in choice_page.dart -
//re-tapping a selected radio is not a gesture people expect to undo anything.
//Without it, a user who picked one could never reach the text field again.
//
//Optional, and the intro says so out loud: this is the field most likely to
//make someone feel inspected, so the page opens by telling them they can skip
//it.
//
//Pops with the new value ('' when cleared), or null if nothing changed.

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/widgets/primary_button.dart';

//short on purpose: this is a label beside a name, not a sentence
const int kPronounsMaxLength = 20;

class PronounsPage extends StatefulWidget {
  final String? initialValue;

  const PronounsPage({super.key, this.initialValue});

  @override
  State<PronounsPage> createState() => _PronounsPageState();
}

class _PronounsPageState extends State<PronounsPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  //null when the saved value is custom text (or there is none)
  String? _selected;
  late final TextEditingController _custom;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue ?? '';
    final isOption = kChoicePronouns.options.contains(initial);
    _selected = isOption ? initial : null;
    _custom = TextEditingController(text: isOption ? '' : initial);
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  //a radio wins when one is picked; otherwise whatever was typed
  String get _value => _selected ?? _custom.text.trim();

  void _select(String? option) {
    setState(() => _selected = option);
    //a picked radio locks the text field, so get the keyboard out of the way
    if (option != null) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    //a picked radio IS the answer, so the free-text alternative is disabled
    final locked = _selected != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(catalogueLabel(text, kChoicePronouns.title)),
          automaticallyImplyLeading: true,
          actions: [
            //the only way back to "no answer" - and what unlocks the text field
            if (locked)
              TextButton(
                onPressed: () => _select(null),
                child: Text(text.clear),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              text.pronounsIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            RadioGroup<String>(
              groupValue: _selected,
              onChanged: _select,
              child: Column(
                children: [
                  for (final option in kChoicePronouns.options)
                    RadioListTile<String>(
                      value: option,
                      title: Text(catalogueLabel(text, option)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -4,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            //Dimmed AND untouchable while a radio is selected: the opacity says
            //"not available", IgnorePointer makes it true. Opacity alone still
            //accepts taps and opens the keyboard.
            IgnorePointer(
              ignoring: locked,
              child: AnimatedOpacity(
                opacity: locked ? 0.4 : 1,
                duration: const Duration(milliseconds: 150),
                child: TextField(
                  controller: _custom,
                  maxLength: kPronounsMaxLength,
                  textCapitalization: TextCapitalization.none,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: text.pronounsCustom,
                    hintText: text.pronounsCustomHint,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            if (locked)
              Text(
                text.pronounsCustomLocked,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: PrimaryButton(
            label: text.save,
            onPressed: () => Navigator.pop(context, _value),
          ),
        ),
      ),
    );
  }
}
