//Show the change, send it, and on failure put the old value back and say so.
//
//Shared by every page that edits the user row one field at a time: Account
//Settings, Edit Profile and Date Preferences. The revert logic itself lives in
//ProfileProvider.saveField; this adds the snackbar.
//
//Everything that touches context is read BEFORE the await, because the page
//may be gone by the time the request returns.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:provider/provider.dart';

Future<void> saveProfileField<T>(
  BuildContext context, {
  required T Function(UserModel user) read,
  required UserModel Function(UserModel user, T value) write,
  required T value,
  required Future<void> Function(String uid) send,
}) async {
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final errorMessage = AppLocalizations.of(context)!.errorOccured;

  final saved = await profileProvider.saveField<T>(
    read: read,
    write: write,
    value: value,
    send: send,
  );

  //the old value has already been restored by the time this shows
  if (!saved) {
    messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
  }
}
