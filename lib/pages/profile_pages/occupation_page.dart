//The Occupation category: job, volunteering, and anything that fits neither.
//
//Three free-text fields, all optional. Students often have no job, so nothing
//here is required and an empty page is a valid answer.
//
//Pops with a Map<String, dynamic> of the three fields.

import 'package:flutter/material.dart';
import 'package:foitifinder/widgets/primary_button.dart';

class OccupationPage extends StatefulWidget {
  final String? initialJob;
  final String? initialVolunteering;
  final String? initialOther;

  const OccupationPage({
    super.key,
    this.initialJob,
    this.initialVolunteering,
    this.initialOther,
  });

  @override
  State<OccupationPage> createState() => _OccupationPageState();
}

class _OccupationPageState extends State<OccupationPage> {
  late final TextEditingController _jobController;
  late final TextEditingController _volunteeringController;
  late final TextEditingController _otherController;

  @override
  void initState() {
    super.initState();
    _jobController = TextEditingController(text: widget.initialJob ?? '');
    _volunteeringController =
        TextEditingController(text: widget.initialVolunteering ?? '');
    _otherController = TextEditingController(text: widget.initialOther ?? '');
  }

  @override
  void dispose() {
    _jobController.dispose();
    _volunteeringController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _result => {
        'job': _jobController.text.trim(),
        'volunteering': _volunteeringController.text.trim(),
        'occupation_other': _otherController.text.trim(),
      };

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
            title: const Text('Occupation'),
            automaticallyImplyLeading: true,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                'All optional - fill in whatever applies.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _jobController,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Job',
                  hintText: 'e.g. Barista at a coffee shop',
                ),
              ),
              TextField(
                controller: _volunteeringController,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Volunteering',
                  hintText: 'e.g. Animal shelter every Sunday',
                ),
              ),
              TextField(
                controller: _otherController,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Other',
                  hintText: 'Anything else you do',
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: PrimaryButton(
              label: 'Save',
              onPressed: () => Navigator.pop(context, _result),
            ),
          ),
        ),
      ),
    );
  }
}
