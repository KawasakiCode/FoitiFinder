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
