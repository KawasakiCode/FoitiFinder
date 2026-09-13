//Checkboxes are ROUND, so multi-answer lists match the round radio buttons of
//single-answer lists instead of looking like a different control.
//
//The shape comes from the app theme (checkboxTheme in AppTheme._build), not
//from each CheckboxListTile, so this checks both the theme itself and that the
//shared choice dialog actually picks it up.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/profile_pages/shared/choice_dialog.dart';
import 'package:foitifinder/theme/app_theme.dart';

//a page with one button that opens the choice dialog for [choice]
Future<void> _openDialog(
  WidgetTester tester,
  ThemeData theme,
  ProfileChoice choice,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showChoiceDialog(context, choice: choice),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
    group('${entry.key} theme', () {
      test('checkboxes are round', () {
        expect(entry.value.checkboxTheme.shape, isA<CircleBorder>());
      });

      testWidgets('multi-answer dialog draws round checkboxes', (tester) async {
        await _openDialog(tester, entry.value, kPrefAlcohol);

        final boxes = find.byType(Checkbox);
        expect(boxes, findsNWidgets(kPrefAlcohol.options.length));
        //the shape the Checkbox actually resolves: its own, else the theme's
        final checkbox = tester.widget<Checkbox>(boxes.first);
        final resolved = checkbox.shape ??
            Theme.of(tester.element(boxes.first)).checkboxTheme.shape;
        expect(resolved, isA<CircleBorder>());
      });

      testWidgets('single-answer dialog still uses radio buttons', (tester) async {
        await _openDialog(tester, entry.value, kChoiceAlcohol);

        expect(find.byType(RadioListTile<String>),
            findsNWidgets(kChoiceAlcohol.options.length));
        expect(find.byType(Checkbox), findsNothing);
      });
    });
  }
}
