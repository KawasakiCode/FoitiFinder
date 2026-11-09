//Generic stand-in for a profile section that has no screen yet.
//
//One page rather than a file per unbuilt section: they would all be the same
//scaffold with a different title, and a real page replaces this by changing one
//line at the call site.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/widgets/polish.dart';

class ComingSoonPage extends StatelessWidget {
  final String title;

  const ComingSoonPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;

    return GlassScaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: true),
      body: CustomScrollView(
        slivers: [
          const SliverGlassBarInset(),
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.construction_outlined,
              message: text.comingSoon,
            ),
          ),
        ],
      ),
    );
  }
}
