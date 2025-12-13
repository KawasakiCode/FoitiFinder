//inkwell widget that wait for its animation to complete before running the onTap method
//ensures no visual bugs occur where the animation lags because of workload 

import 'package:flutter/material.dart';

class DelayedInkWell extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final int delayMs; // Allow override if needed

  const DelayedInkWell({
    super.key,
    required this.onTap,
    required this.child,
    required this.delayMs , // Your "Goldilocks" default
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10), // Match your standard radius
      onTap: onTap == null 
          ? null 
          : () async {
              // 1. Play animation
              await Future.delayed(Duration(milliseconds: delayMs));
              // 2. Run logic
              onTap!();
            },
      child: child,
    );
  }
}