//This file wraps the ui of main and other pages 
//It has 2 attributes isLoading and child
//Child is the first widget of the ui you want to wrap
//isLoading is a boolean flag used to tell this widget when to show a throbber
//isLoading needs to be handled in the page you wrap for this to work
//Note this goes at the body property of the Scaffold not instead of the Scaffold

import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. The main screen UI passes right through
        child, 
        
        // 2. The Throbber Overlay
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}