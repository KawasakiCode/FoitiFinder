//Which match a tapped notification opens.
//
//THE WHOLE FEATURE TURNS ON ONE LINE, and its failure mode is silence: if the
//id does not come out of the payload the banner opens the matches list and
//the user is back to hunting for the row, with nothing anywhere to say the
//parse failed. So the parse is a function, and this is it.
//
//WHAT IS NOT HERE is the navigation. MatchesPageState.openMatch reaches for
//FirebaseAuth and ApiService, so it cannot be pumped - the same limit as
//match_actions_test - and the server half (that match_id reaches the data
//payload at all, as a string, for both kinds) is checked in
//backend/tests/test_push_gating.py.

import 'package:flutter_test/flutter_test.dart';
import 'package:foitifinder/main_screen.dart';

void main() {
  test('a normal payload names the match', () {
    expect(matchIdFromPush({'type': 'match', 'match_id': '57'}), 57);
  });

  test('an int survives too', () {
    //FCM sends strings, but nothing stops a future sender putting an int in -
    //and a cast would throw where toString simply works
    expect(matchIdFromPush({'match_id': 57}), 57);
  });

  group('and every payload that does not name one means the list', () {
    test('no match_id at all', () {
      //an older backend, before the id was added
      expect(matchIdFromPush({'type': 'match'}), isNull);
    });

    test('an empty string', () {
      expect(matchIdFromPush({'match_id': ''}), isNull);
    });

    test('the literal None', () {
      //what str(None) produces, which is why the backend omits the key
      //instead of sending it - a second spelling of null
      expect(matchIdFromPush({'match_id': 'None'}), isNull);
    });

    test('something that is not a number', () {
      expect(matchIdFromPush({'match_id': 'seventeen'}), isNull);
    });

    test('an empty payload', () {
      expect(matchIdFromPush({}), isNull);
    });
  });
}
