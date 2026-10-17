//Cleaning up whatever the user typed into an Instagram handle.
//
//NORMALISING, NOT VALIDATING. Meta shut the Instagram Basic Display API down
//in December 2024 and its replacements need a Business or Creator account, so
//for a student on a personal account there is no way to check that a handle
//exists or that it belongs to them. What is left is making sure the thing we
//store is shaped like a handle - and it matters more here than for any other
//field, because with no chat in the app the handle IS the payoff of a match.
//
//THE SAME RULES RUN ON THE SERVER (backend/instagram.py), and that is not
//duplication for its own sake: here it exists so the user sees what will be
//saved while they are still looking at the field, and there it exists because
//an old or patched client must not be able to write rubbish into the column.
//If you change one, change the other - backend/tests/test_instagram.py and
//test/instagram_handle_test.dart are deliberately the same cases.

//Instagram's own rule: letters, digits, full stops and underscores, up to 30.
final RegExp _handle = RegExp(r'^[a-z0-9._]{1,30}$');

const int kInstagramHandleMaxLength = 30;

/// The bare lowercase handle, or null if what was typed cannot be one.
///
/// Null means "this is not a handle", for the caller to reject. It never means
/// "the user cleared it": the handle is required and has no Clear button,
/// because an account without one cannot match.
String? normaliseInstagramHandle(String? raw) {
  if (raw == null) return null;

  var value = raw.trim();
  if (value.isEmpty) return null;

  //a pasted profile link: keep the first path segment after the host. Done
  //first, so the query string of a share link can never be mistaken for part
  //of the name.
  final lowered = value.toLowerCase();
  if (lowered.contains('instagram.com')) {
    value = lowered.split('instagram.com').last;
    //leading slashes from the URL
    while (value.startsWith('/')) {
      value = value.substring(1);
    }
  }

  //share links carry ?igsh=..., and a copy from the browser bar can bring a
  //#fragment along
  final cut = value.indexOf(RegExp(r'[?#]'));
  if (cut >= 0) value = value.substring(0, cut);

  //"@maria" is how people write a handle; a trailing slash is what a URL
  //leaves behind
  value = value.trim();
  if (value.startsWith('@')) value = value.substring(1);
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  value = value.trim().toLowerCase();

  if (!_handle.hasMatch(value)) return null;
  //Instagram allows full stops inside a handle but not at either end, and
  //never two in a row. Checked separately so the message is not a regex.
  if (value.startsWith('.') || value.endsWith('.') || value.contains('..')) {
    return null;
  }

  return value;
}
