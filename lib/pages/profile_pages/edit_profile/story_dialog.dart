//Write, edit or clear the story behind one photo.
//
//Shared by the photo stories list and the single-photo page, so the two can
//never offer a different editor for the same thing.
//
//Returns the new text, '' to clear it, or null if the user dismissed the
//dialog - null means "unchanged", which is NOT the same as an empty string.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/widgets/app_dialog.dart';

//A CAPTION, NOT A PARAGRAPH. 150 is enough for "this was five minutes before
//it started raining" and not enough to retell the holiday - the bio is where
//prose belongs. Breeze lands in the same place.
const int kStoryMaxLength = 150;

Future<String?> showStoryDialog(
  BuildContext context, {
  String? initialStory,
}) {
  final text = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: initialStory ?? '');
  final hadStory = (initialStory ?? '').isNotEmpty;

  return showAppDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(hadStory ? text.editStory : text.addStory),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        maxLength: kStoryMaxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: text.storyHint),
      ),
      actions: [
        //only offer removal when there is something to remove
        if (hadStory)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: Text(
              text.removeStory,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(text.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(text.save),
        ),
      ],
    ),
  );
}
