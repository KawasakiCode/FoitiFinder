//The Education category: university, major, and whether they are still studying.
//
//The university is NOT editable. It is derived from the email address the
//account was verified with, which is the whole point of gating signup on
//university domains - a typed-in university would be worth nothing, while a
//derived one is as trustworthy as the email verification behind it.
//
//DISPLAY ONLY here: when this reaches the backend, the server must derive the
//university from the verified token's email itself and ignore anything the
//client sends for it. Otherwise the guarantee evaporates.
//
//Pops with a Map<String, dynamic> of the editable fields.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/constants/university_domains.dart';
import 'package:foitifinder/widgets/primary_button.dart';

class EducationPage extends StatefulWidget {
  final String? initialMajor;
  final bool? initialIsCurrentlyStudying;

  const EducationPage({
    super.key,
    this.initialMajor,
    this.initialIsCurrentlyStudying,
  });

  @override
  State<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> {
  late final TextEditingController _majorController;
  late bool _isCurrentlyStudying;

  @override
  void initState() {
    super.initState();
    _majorController = TextEditingController(text: widget.initialMajor ?? '');
    _isCurrentlyStudying = widget.initialIsCurrentlyStudying ?? false;
  }

  @override
  void dispose() {
    _majorController.dispose();
    super.dispose();
  }

  //null when the address isn't one we recognise - which shouldn't happen, since
  //signup rejects those, but an unknown domain must not crash the page
  String? get _university =>
      universityNameForEmail(FirebaseAuth.instance.currentUser?.email);

  Map<String, dynamic> get _result => {
        'major': _majorController.text.trim(),
        'is_currently_studying': _isCurrentlyStudying,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final university = _university;

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
            title: const Text('Education'),
            automaticallyImplyLeading: true,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text('University', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              //read-only on purpose: it comes from the verified email
              InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.verified_outlined),
                ),
                child: Text(
                  university ?? 'Not detected',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Taken from your student email and cannot be changed.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),

              Text('Major', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              //free text rather than a picker: Greek universities between them
              //run hundreds of programmes, and a wrong list is worse than none.
              //An autocomplete can be layered on later without a schema change.
              TextField(
                controller: _majorController,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Applied Informatics',
                ),
              ),
              const SizedBox(height: 8),

              CheckboxListTile(
                value: _isCurrentlyStudying,
                title: const Text("I'm currently studying"),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) =>
                    setState(() => _isCurrentlyStudying = v ?? false),
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
