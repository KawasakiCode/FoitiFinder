//An icon for each profile category, so a pill reading "Never" says what it is
//never about.
//
//"A long-term relationship" stands on its own. "Never", "Sometimes" and "Yes"
//do not - three of the four categories share the same answers, so without an
//icon a profile shows three identical pills meaning three different things.
//
//ONE ICON PER CATEGORY, not per answer. The icon names the subject and the
//words carry the answer: a stroller means "kids", and "I don't want kids" is
//already the whole sentence next to it. Swapping in crossed-out variants makes
//the pills louder than the text they are labelling.
//
//MATERIAL ICONS, not drawings of our own and not anyone else's: they ship with
//Flutter (Apache 2.0), every user has seen them in a hundred other apps, and
//they cost nothing to render at any size.

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/profile_options.dart';

//Keyed by ProfileChoice.key, which is also the backend column name.
const Map<String, IconData> kChoiceIcons = {
  'alcohol': Icons.wine_bar_outlined,
  'smoking': Icons.smoking_rooms_outlined,
  'kids': Icons.stroller_outlined,
  'dating_intention': Icons.favorite_outline,
  'sexual_orientation': Icons.diversity_1_outlined,
  'pronouns': Icons.badge_outlined,
  'religion': Icons.self_improvement_outlined,
  'political_view': Icons.how_to_vote_outlined,
};

IconData? iconForChoice(ProfileChoice choice) => kChoiceIcons[choice.key];
