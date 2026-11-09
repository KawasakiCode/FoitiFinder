//The Occupation category: job and volunteering.
//
//Two free-text fields, both optional. Students often have neither, so nothing
//here is required and an empty page is a valid answer.
//
//Pops with a Map<String, dynamic> of the two fields.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:foitifinder/widgets/primary_button.dart';

class OccupationPage extends StatefulWidget {
  final String? initialJob;
  final String? initialVolunteering;

  const OccupationPage({
    super.key,
    this.initialJob,
    this.initialVolunteering,
  });

  @override
  State<OccupationPage> createState() => _OccupationPageState();
}

class _OccupationPageState extends State<OccupationPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  late final TextEditingController _jobController;
  late final TextEditingController _volunteeringController;

  @override
  void initState() {
    super.initState();
    _jobController = TextEditingController(text: widget.initialJob ?? '');
    _volunteeringController =
        TextEditingController(text: widget.initialVolunteering ?? '');
  }

  @override
  void dispose() {
    _jobController.dispose();
    _volunteeringController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _result => {
        'job': _jobController.text.trim(),
        'volunteering': _volunteeringController.text.trim(),
      };

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.pop(context, _result);
        },
        child: GlassScaffold(
          appBar: AppBar(
            title: Text(text.occupation),
            automaticallyImplyLeading: true,
          ),
          body: GlassScroll(
            slivers: [
              SliverStagger(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                children: [
                  Text(text.occupationAllOptional, style: mutedText(context)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _jobController,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: text.job,
                      hintText: text.jobHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _volunteeringController,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: text.volunteering,
                      hintText: text.volunteeringHint,
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottomBar: PrimaryButton(
            label: text.save,
            onPressed: () => Navigator.pop(context, _result),
          ),
        ),
      ),
    );
  }
}
