// Whitelist of Greek university email domains used to gate signup.
//
// These are the *registrable root* domains of the 24 public universities
// (ΑΕΙ) in Greece, per the official Study in Greece portal, plus ASPETE.
// The signup check accepts a domain if it equals one of these OR ends with
// ".<root>", so department/service subdomains (e.g. di.uoa.gr, mail.ntua.gr,
// isc.tuc.gr) are automatically covered — no need to list every subdomain.
//
// A couple of institutions issue student mail on a separate root that is NOT
// a subdomain of the main site; those are listed explicitly (e.g. upnet.gr
// for Patras students, uom.edu.gr for UoM students).
//
// NOTE: HARICA (harica.gr) is the authoritative source for Greek academic
// domains but does not publish a machine-readable list. Verify against it if
// a legitimate student is ever rejected, and add the missing root here.
const Set<String> kUniversityDomains = {
  'uoa.gr',        // National and Kapodistrian University of Athens
  'ntua.gr',       // National Technical University of Athens
  'asfa.gr',       // Athens School of Fine Arts
  'aua.gr',        // Agricultural University of Athens
  'aueb.gr',       // Athens University of Economics and Business
  'auth.gr',       // Aristotle University of Thessaloniki
  'panteion.gr',   // Panteion University
  'unipi.gr',      // University of Piraeus
  'uom.gr',        // University of Macedonia (staff)
  'uom.edu.gr',    // University of Macedonia (students)
  'upatras.gr',    // University of Patras
  'upnet.gr',      // University of Patras (student network)
  'uoi.gr',        // University of Ioannina
  'duth.gr',       // Democritus University of Thrace
  'uoc.gr',        // University of Crete
  'tuc.gr',        // Technical University of Crete
  'uth.gr',        // University of Thessaly
  'aegean.gr',     // University of the Aegean
  'ionio.gr',      // Ionian University
  'hua.gr',        // Harokopio University of Athens
  'uop.gr',        // University of the Peloponnese
  'eap.gr',        // Hellenic Open University
  'uowm.gr',       // University of Western Macedonia
  'ihu.gr',        // International Hellenic University
  'ihu.edu.gr',    // International Hellenic University (alt)
  'uniwa.gr',      // University of West Attica
  'hmu.gr',        // Hellenic Mediterranean University
  'aspete.gr',     // ASPETE (School of Pedagogical & Technological Education)
};

// Domain -> display name, used to auto-fill the university on the education
// page from the address the user signed up with.
//
// Matched the same way as kUniversityDomains: exact match, or a subdomain of
// one of these roots. Every key here MUST also be in kUniversityDomains above,
// or a student could be gated out at signup and still see a university name.
//
// SERVER SIDE TOO: the backend derives this from the verified token's email
// rather than trusting the client, so this map is for DISPLAY only. Mirrors
// backend/university_domains.py.
const Map<String, String> kUniversityNames = {
  'uoa.gr': 'National and Kapodistrian University of Athens',
  'ntua.gr': 'National Technical University of Athens',
  'asfa.gr': 'Athens School of Fine Arts',
  'aua.gr': 'Agricultural University of Athens',
  'aueb.gr': 'Athens University of Economics and Business',
  'auth.gr': 'Aristotle University of Thessaloniki',
  'panteion.gr': 'Panteion University',
  'unipi.gr': 'University of Piraeus',
  'uom.gr': 'University of Macedonia',
  'uom.edu.gr': 'University of Macedonia',
  'upatras.gr': 'University of Patras',
  'upnet.gr': 'University of Patras',
  'uoi.gr': 'University of Ioannina',
  'duth.gr': 'Democritus University of Thrace',
  'uoc.gr': 'University of Crete',
  'tuc.gr': 'Technical University of Crete',
  'uth.gr': 'University of Thessaly',
  'aegean.gr': 'University of the Aegean',
  'ionio.gr': 'Ionian University',
  'hua.gr': 'Harokopio University of Athens',
  'uop.gr': 'University of the Peloponnese',
  'eap.gr': 'Hellenic Open University',
  'uowm.gr': 'University of Western Macedonia',
  'ihu.gr': 'International Hellenic University',
  'ihu.edu.gr': 'International Hellenic University',
  'uniwa.gr': 'University of West Attica',
  'hmu.gr': 'Hellenic Mediterranean University',
  'aspete.gr': 'ASPETE - School of Pedagogical and Technological Education',
};

/// The city each institution is seated in, used to prefill a new user's place
/// of residence at signup so almost nobody has to type it.
///
/// SEAT, not campus. Several of these are genuinely multi-city - Democritus
/// spans Komotini, Xanthi, Alexandroupoli and Orestiada; the Aegean spans six
/// islands; the Peloponnese spans five towns - so this is a best guess, which
/// is exactly why the Place of residence row lets the user change it.
///
/// Stored in English like every other canonical string in the app (see
/// l10n/catalogue_labels.dart for the same reasoning): the value goes in the
/// database and must not change meaning when the user switches language.
const Map<String, String> kUniversityCities = {
  'uoa.gr': 'Athens',
  'ntua.gr': 'Athens',
  'asfa.gr': 'Athens',
  'aua.gr': 'Athens',
  'aueb.gr': 'Athens',
  'panteion.gr': 'Athens',
  'hua.gr': 'Athens',
  'uniwa.gr': 'Athens',
  'aspete.gr': 'Athens',
  'unipi.gr': 'Piraeus',
  'auth.gr': 'Thessaloniki',
  'uom.gr': 'Thessaloniki',
  'uom.edu.gr': 'Thessaloniki',
  'ihu.gr': 'Thessaloniki',
  'ihu.edu.gr': 'Thessaloniki',
  'upatras.gr': 'Patras',
  'upnet.gr': 'Patras',
  'eap.gr': 'Patras',
  'uoi.gr': 'Ioannina',
  'duth.gr': 'Komotini',
  'uoc.gr': 'Rethymno',
  'tuc.gr': 'Chania',
  'hmu.gr': 'Heraklion',
  'uth.gr': 'Volos',
  'aegean.gr': 'Mytilene',
  'ionio.gr': 'Corfu',
  'uop.gr': 'Tripoli',
  'uowm.gr': 'Kozani',
};

/// The city behind an email address, or null if the domain isn't one we know.
/// Longest match wins, same as [universityNameForEmail].
String? cityForEmail(String? email) => _matchDomain(email, kUniversityCities);

String? _matchDomain(String? email, Map<String, String> table) {
  if (email == null || !email.contains('@')) return null;
  final domain = email.split('@').last.toLowerCase().trim();

  String? best;
  int bestLength = -1;
  for (final entry in table.entries) {
    final root = entry.key;
    if (domain == root || domain.endsWith('.$root')) {
      if (root.length > bestLength) {
        bestLength = root.length;
        best = entry.value;
      }
    }
  }
  return best;
}

/// The university behind an email address, or null if the domain isn't one we
/// know. Longest match wins so 'uom.edu.gr' is not shadowed by 'uom.gr'.
String? universityNameForEmail(String? email) {
  if (email == null || !email.contains('@')) return null;
  final domain = email.split('@').last.toLowerCase().trim();

  String? best;
  int bestLength = -1;
  for (final entry in kUniversityNames.entries) {
    final root = entry.key;
    if (domain == root || domain.endsWith('.$root')) {
      if (root.length > bestLength) {
        bestLength = root.length;
        best = entry.value;
      }
    }
  }
  return best;
}
