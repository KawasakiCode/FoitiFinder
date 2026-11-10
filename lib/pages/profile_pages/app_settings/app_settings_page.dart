//The settings page: app-level preferences only.
//
//Deliberately small: appearance, notifications and language. Discovery
//filters live in DatePreferencesPage, log out and delete account in
//AccountSettingsPage, and the legal documents in the About section on the
//profile page.
//
//Settings changed here are monitored by SettingsProvider and stored in
//SharedPreferences.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/widgets/app_dialog.dart';
import 'package:foitifinder/widgets/nav_row.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  //THE SWITCH SAID NO AND THE USER NEEDS TO KNOW WHY. Android stops asking
  //after two refusals, so at this point the OS prompt will not appear again
  //however many times the switch is tapped - the only route back is the
  //system settings screen, which openAppSettings opens directly.
  Future<void> _explainMissingPermission(BuildContext context) async {
    final text = AppLocalizations.of(context)!;
    final open = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.notificationsBlockedTitle),
        content: Text(text.notificationsBlockedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text.notificationsBlockedAction),
          ),
        ],
      ),
    );
    if (open == true) await openAppSettings();
  }

  AppLocalizations get text => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return GlassScaffold(
      appBar: PageAppBar(title: text.settingsTitle),
      body: GlassScroll(
        slivers: [
          SliverStagger(
            padding: EdgeInsets.zero,
            children: [
              //Appearance dark mode
              SectionHeader(text.appearance),
              CardGroup(
                children: [
                  SwitchRow(
                    label: text.darkMode,
                    value: settings.themeMode == ThemeMode.dark,
                    onChanged: (bool value) => settings.toggleTheme(value),
                  ),
                ],
              ),
              //Notifications
              SectionHeader(text.notifications),
              CardGroup(
                children: [
                  SwitchRow(
                    label: text.matchNotifications,
                    value: settings.matchNotificationsEnabled,
                    onChanged: (bool enabled) async {
                      final ok = await settings
                          .toggleMatchNotifications(enabled);
                      //IT CAN ONLY FAIL ONE WAY: the OS refused, and
                      //after two refusals Android stops asking, so
                      //the switch alone can never turn it back on.
                      //Saying so - and offering the one screen that
                      //can - is the difference between a setting and
                      //a switch that bounces.
                      if (!ok && context.mounted) {
                        await _explainMissingPermission(context);
                      }
                    },
                  ),
                  AnimatedSize(
                    duration: AppMotion.base,
                    curve: AppMotion.standard,
                    alignment: Alignment.topLeft,
                    child: settings.osPermission
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    text.notificationsWarning,
                                    style: mutedText(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
              //Language
              SectionHeader(text.language),
              CardGroup(
                dividers: true,
                children: [
                  CheckRow(
                    label: text.greek,
                    selected: settings.locale == Locale('el'),
                    onTap: () {
                      settings.changeLanguage('el');
                    },
                  ),
                  CheckRow(
                    label: text.english,
                    selected: settings.locale == Locale('en'),
                    onTap: () {
                      settings.changeLanguage('en');
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
