//Internet connection wrapper
//if it detects a connection loss it pushes a no internet page 
//when the wifi comes back again it automatically returns to the page it was

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

class InternetWrapper extends StatefulWidget {
  final Widget child;

  const InternetWrapper({super.key, required this.child});

  @override
  State<InternetWrapper> createState() => _InternetWrapperState();
}

class _InternetWrapperState extends State<InternetWrapper> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _wasOffline = false; 

  AppLocalizations get text => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    // Start listening in the background
    _subscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Determine if we have absolutely no connection
    final bool isOffline = results.isEmpty || results.contains(ConnectivityResult.none);

    if (isOffline) {
      _wasOffline = true;
      _showSnackBar(
        message: text.lostInternet,
        color: const Color.fromARGB(255, 79, 215, 233),
        duration: const Duration(seconds: 3),
      );
    } else {
      // Only show the green success message if they were previously offline
      if (_wasOffline) {
        _wasOffline = false;
        
        // Hide the persistent red SnackBar first
        globalMessengerKey.currentState?.hideCurrentSnackBar();
        
        _showSnackBar(
          message: text.backOnline,
          color: const Color.fromARGB(255, 79, 215, 233),
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _showSnackBar({required String message, required Color color, required Duration duration}) {
    globalMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // We always return the child. The UI never gets destroyed.
    return widget.child; 
  }
}
