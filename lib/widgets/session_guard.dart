//checks if the logged user does exist
//firebase automaticaly checks cached files from the phone and not the server
//this forces firebase to check with the server first

//called strictly by main.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/main_screen.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';

class SessionGuard extends StatefulWidget {
  final User user;
  const SessionGuard({super.key, required this.user});

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bgSync();
    });

  }

  Future<void> _bgSync() async {
    await Provider.of<SettingsProvider>(context, listen: false).fetchSettingsFromApi(widget.user.uid);
    if(!mounted)return;
    await Provider.of<ProfileProvider>(context, listen: false).fetchUserFromApi(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}