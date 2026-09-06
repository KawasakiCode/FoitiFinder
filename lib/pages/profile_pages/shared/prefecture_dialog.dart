//Pick a Greek prefecture, with a search box.
//
//A dialog rather than a page: it is one tap once you have typed two letters,
//and a whole screen transition either side of that is more ceremony than the
//answer is worth - the same reasoning as choice_dialog.dart.
//
//54 options is far too many to scroll, so the search box is the interface and
//the list is what is left of it. Two letters narrows it to a handful.
//
//SEARCH MATCHES BOTH LANGUAGES. A Greek user typing "Θεσ" and an English user
//typing "The" must both find Thessaloniki, so each row is tested against its
//canonical English string AND its translated label. Without that, half the
//users would be typing into a box that never matches anything.
//
//Returns the CANONICAL ENGLISH name, or '' if the user cleared it, or null if
//they dismissed the dialog (which means "unchanged").

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/greek_prefectures.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/widgets/pressable.dart';
import 'package:foitifinder/widgets/app_dialog.dart';

Future<String?> showPrefectureDialog(
  BuildContext context, {
  String? initialSelected,
}) {
  return showAppDialog<String>(
    context: context,
    builder: (_) => _PrefectureDialog(initialSelected: initialSelected),
  );
}

class _PrefectureDialog extends StatefulWidget {
  final String? initialSelected;

  const _PrefectureDialog({this.initialSelected});

  @override
  State<_PrefectureDialog> createState() => _PrefectureDialogState();
}

class _PrefectureDialogState extends State<_PrefectureDialog> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  //Fold accents and case so "Αχαΐα" is reachable by typing "αχαια", and
  //"Rethymno" by "rethymno". Greek users type without accents constantly.
  String _normalise(String value) {
    const accented = 'άέήίόύώϊϋΐΰΆΈΉΊΌΎΏΪΫ';
    const plain = 'αεηιουωιυιυαεηιουωιυ';
    var out = value.toLowerCase();
    for (var i = 0; i < accented.length; i++) {
      out = out.replaceAll(accented[i], plain[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final query = _normalise(_query.trim());

    final matches = kGreekPrefectures.where((canonical) {
      if (query.isEmpty) return true;
      //the English name and the displayed (possibly Greek) label
      return _normalise(canonical).contains(query) ||
          _normalise(catalogueLabel(text, canonical)).contains(query);
    }).toList();

    return AlertDialog(
      title: Text(text.placeOfResidence),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        //a fixed height so the dialog doesn't resize on every keystroke as the
        //result count changes, which reads as the box jumping around
        height: 360,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: text.search,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        text.noResults,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final canonical = matches[index];
                        final selected = canonical == widget.initialSelected;
                        return Pressable(
                          onTap: () => Navigator.pop(context, canonical),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    catalogueLabel(text, canonical),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: selected
                                          ? theme.colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        //clearing is only offered when there is something to clear
        if ((widget.initialSelected ?? '').isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(text.clear),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(text.cancel),
        ),
      ],
    );
  }
}
