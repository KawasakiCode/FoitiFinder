//The Location category: the city the user is in, as plain text.
//
//DELIBERATELY not GPS. Coordinates would mean location permissions, a distance
//query and a real privacy surface, for an app whose users are already grouped
//by university - and the email domain implies the city anyway. A typed city is
//display only and never filters the feed.
//
//Pops with the city string.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/widgets/primary_button.dart';

class LocationPage extends StatefulWidget {
  final String? initialCity;

  const LocationPage({super.key, this.initialCity});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCity ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _result => _controller.text.trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.pop(context, _result);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(text.location),
            automaticallyImplyLeading: true,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                text.locationPrompt,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: text.locationHint,
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: PrimaryButton(
              label: text.save,
              onPressed: () => Navigator.pop(context, _result),
            ),
          ),
        ),
      ),
    );
  }
}
