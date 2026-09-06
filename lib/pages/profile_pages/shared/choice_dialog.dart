//The dialog form of a pick-from-a-list category.
//
//Short lists (alcohol, smoking, dating intention, kids - 3 to 5 options) do not
//deserve a whole page push: the user answers in one tap and a full screen
//transition either side of that is more ceremony than the answer is worth.
//ChoicePage still exists for the long lists, where a dialog would scroll.
//
//Returns the picks, or null if the user dismissed it - null means "unchanged",
//which is NOT the same as an empty list (that means "cleared").

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/widgets/app_dialog.dart';

Future<List<String>?> showChoiceDialog(
  BuildContext context, {
  required ProfileChoice choice,
  List<String> initialSelected = const [],
}) {
  return showAppDialog<List<String>>(
    context: context,
    builder: (_) => _ChoiceDialog(choice: choice, initial: initialSelected),
  );
}

class _ChoiceDialog extends StatefulWidget {
  final ProfileChoice choice;
  final List<String> initial;

  const _ChoiceDialog({required this.choice, required this.initial});

  @override
  State<_ChoiceDialog> createState() => _ChoiceDialogState();
}

class _ChoiceDialogState extends State<_ChoiceDialog> {
  late final List<String> _selected;

  @override
  void initState() {
    super.initState();
    //copy: dismissing must leave the caller's list untouched
    _selected = List<String>.from(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final choice = widget.choice;
    final isSingle = choice.mode == ChoiceMode.single;

    return AlertDialog(
      title: Text(catalogueLabel(text, choice.title)),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                catalogueLabel(text, choice.subtitle),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 8),
            //a short list, so it fits without scrolling - but stay scrollable
            //anyway for large font settings
            Flexible(
              child: SingleChildScrollView(
                child: isSingle
                    ? RadioGroup<String>(
                        groupValue: _selected.isEmpty ? null : _selected.first,
                        onChanged: (value) => setState(() {
                          _selected
                            ..clear()
                            ..add(value!);
                        }),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final option in choice.options)
                              RadioListTile<String>(
                                value: option,
                                title: Text(catalogueLabel(text, option)),
                              ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final option in choice.options)
                            CheckboxListTile(
                              value: _selected.contains(option),
                              title: Text(catalogueLabel(text, option)),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              onChanged: (_) => setState(() {
                                if (!_selected.remove(option)) {
                                  _selected.add(option);
                                }
                              }),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        //clears the answer rather than cancelling - dismissing does that
        if (_selected.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, const <String>[]),
            child: Text(text.clear),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(text.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            List<String>.unmodifiable(_selected),
          ),
          child: Text(text.save),
        ),
      ],
    );
  }
}
