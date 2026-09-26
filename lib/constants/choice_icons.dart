//An icon for each profile answer, so a pill reading "Never" says what it is
//never about.
//
//"A long-term relationship" stands on its own. "Never", "Sometimes" and "Yes"
//do not - three of the four categories share the same answers, so without an
//icon a profile shows three identical pills meaning three different things.
//
//MATERIAL ICONS, not drawings of our own and not anyone else's: they ship with
//Flutter (Apache 2.0), every user has seen them in a hundred other apps, and
//they cost nothing to render at any size.
//
//THE ANSWER PICKS THE ICON WHERE THE ANSWER FLIPS THE MEANING: "Never" for
//smoking is smoke_free, a crossed-out cigarette, while "Yes" is a lit one. One
//icon per category would have made the pill say "smoking" when the point is
//that they do not. Where the answers are shades of the same thing (kids,
//dating intention) the category's own icon is enough.

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/profile_options.dart';

IconData? iconForAnswer(String choiceKey, String answer) {
  switch (choiceKey) {
    case 'alcohol':
      return answer == 'Never' ? Icons.no_drinks_outlined : Icons.wine_bar_outlined;
    case 'smoking':
      return answer == 'Never' ? Icons.smoke_free_outlined : Icons.smoking_rooms_outlined;
    case 'kids':
      //one icon for every answer: "I want kids" and "I don't want kids" are
      //both about kids, and a crossed-out child reads as hostility rather than
      //as a preference
      return Icons.child_care_outlined;
    case 'dating_intention':
      return Icons.favorite_outline;
    case 'sexual_orientation':
      return Icons.diversity_1_outlined;
    case 'pronouns':
      return Icons.badge_outlined;
    case 'religion':
      return Icons.self_improvement_outlined;
    case 'political_view':
      return Icons.how_to_vote_outlined;
    default:
      return null;
  }
}

//Convenience for callers that already hold the ProfileChoice.
IconData? iconForChoice(ProfileChoice choice, String answer) =>
    iconForAnswer(choice.key, answer);
