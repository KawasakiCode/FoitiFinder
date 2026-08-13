//Page where the user picks the interests (hobbies/lifestyle tags) shown on
//their profile.
//
//BACKBONE ONLY: the catalogue of interests and the category layout are still
//being decided, so the body is intentionally empty. Everything needed to fill
//it in later is already wired up: selection state, the max-selection cap and
//the save handler.
//
//NAMING WARNING: UserModel.interests already exists and means something else —
//it is the comma separated gender preference ("Men"/"Women"/"Everyone") read by
//interests_to_genders() in the backend. These tags are a separate concept, so
//they are kept in their own field here (_selected) and must NOT be persisted
//into that column. Pick a distinct name (e.g. interest_tags / hobbies) when the
//backend side is added.

import 'package:flutter/material.dart';

class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key});

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  //how many tags a user may display. Bumble caps at 5, Tinder at 3-5; revisit
  //once the catalogue is settled.
  static const int maxSelections = 5;

  //the interests the user has picked, in pick order — the order matters if we
  //ever show "top interests" first the way Tinder does
  final List<String> _selected = [];

  bool get _canSelectMore => _selected.length < maxSelections;

  bool isSelected(String interest) => _selected.contains(interest);

  //toggle a tag on/off, refusing new picks once the cap is reached
  void toggleInterest(String interest) {
    setState(() {
      if (_selected.remove(interest)) return;
      if (!_canSelectMore) return;
      _selected.add(interest);
    });
  }

  //TODO: persist the selection once the backend field exists. Deliberately
  //local-only for now so nothing writes to the gender-preference column.
  void save() {
    Navigator.of(context).pop(List<String>.unmodifiable(_selected));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //TODO: move to l10n (app_en.arb / app_el.arb) once the page has content
        title: const Text('Interests'),
        automaticallyImplyLeading: true,
      ),
      //empty on purpose — the category sections and chips land here
      body: const SizedBox.shrink(),
    );
  }
}
