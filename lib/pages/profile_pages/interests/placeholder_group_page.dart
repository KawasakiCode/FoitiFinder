//Stand-in page for a catalogue group that has no mechanic yet - currently
//only Q&A's.
//
//It is declared in the catalogue with a `placeholder` string and no sections,
//because it is not a grid of tappable boxes but prompt/answer pairs. This page
//renders whichever group it is given and shows that group's own placeholder
//text, so a second such group costs nothing.
//
//Replace with a real page per group once the mechanic is decided; the routing
//on the profile page is the only thing that has to change.

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/interest_catalogue.dart';

class PlaceholderGroupPage extends StatelessWidget {
  final InterestGroup group;

  const PlaceholderGroupPage({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                group.placeholder ?? 'Coming soon.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
