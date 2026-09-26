# Whitelist of Greek university email domains used to gate account creation.
#
# This is the backend mirror of lib/constants/university_domains.dart in the
# app repo. Keep the two in sync when adding/removing an institution.
#
# These are the *registrable root* domains of the 24 public universities
# (AEI) in Greece, per the official Study in Greece portal, plus ASPETE.
# The domain check should accept an email domain if it equals one of these OR
# ends with ".<root>", so department/service subdomains (e.g. di.uoa.gr,
# mail.ntua.gr, isc.tuc.gr) are covered automatically without listing each.
#
# A couple of institutions issue student mail on a separate root that is NOT
# a subdomain of the main site; those are listed explicitly (e.g. upnet.gr
# for Patras students, uom.edu.gr for UoM students).
#
# NOTE: HARICA (harica.gr) is the authoritative source for Greek academic
# domains but does not publish a machine-readable list. Verify against it if
# a legitimate student is ever rejected, and add the missing root here.

UNIVERSITY_DOMAINS: frozenset[str] = frozenset({
    "uoa.gr",        # National and Kapodistrian University of Athens
    "ntua.gr",       # National Technical University of Athens
    "asfa.gr",       # Athens School of Fine Arts
    "aua.gr",        # Agricultural University of Athens
    "aueb.gr",       # Athens University of Economics and Business
    "auth.gr",       # Aristotle University of Thessaloniki
    "panteion.gr",   # Panteion University
    "unipi.gr",      # University of Piraeus
    "uom.gr",        # University of Macedonia (staff)
    "uom.edu.gr",    # University of Macedonia (students)
    "upatras.gr",    # University of Patras
    "upnet.gr",      # University of Patras (student network)
    "uoi.gr",        # University of Ioannina
    "duth.gr",       # Democritus University of Thrace
    "uoc.gr",        # University of Crete
    "tuc.gr",        # Technical University of Crete
    "uth.gr",        # University of Thessaly
    "aegean.gr",     # University of the Aegean
    "ionio.gr",      # Ionian University
    "hua.gr",        # Harokopio University of Athens
    "uop.gr",        # University of the Peloponnese
    "eap.gr",        # Hellenic Open University
    "uowm.gr",       # University of Western Macedonia
    "ihu.gr",        # International Hellenic University
    "ihu.edu.gr",    # International Hellenic University (alt)
    "uniwa.gr",      # University of West Attica
    "hmu.gr",        # Hellenic Mediterranean University
    "aspete.gr",     # ASPETE (School of Pedagogical & Technological Education)
})


def is_university_email(email: str | None) -> bool:
    """True if `email` belongs to a whitelisted university domain.

    Mirrors the client-side check in lib/pages/auth_pages/signup.dart: the
    domain matches if it equals a whitelisted root or is a subdomain of one.
    A missing/malformed address is rejected rather than let through.
    """
    if not email or "@" not in email:
        return False

    #rsplit: everything before the last '@' is the local part, which may itself
    #contain quoted '@' characters
    domain = email.rsplit("@", 1)[1].strip().lower().rstrip(".")
    if not domain:
        return False

    return any(
        domain == allowed or domain.endswith(f".{allowed}")
        for allowed in UNIVERSITY_DOMAINS
    )

# The institution behind each domain, mirroring kUniversityNames in
# lib/constants/university_domains.dart. Two roots can map to the same
# university (staff vs student mail), which is fine - the NAME is what is
# stored, never the domain.
UNIVERSITY_NAMES: dict[str, str] = {
    "uoa.gr": "National and Kapodistrian University of Athens",
    "ntua.gr": "National Technical University of Athens",
    "asfa.gr": "Athens School of Fine Arts",
    "aua.gr": "Agricultural University of Athens",
    "aueb.gr": "Athens University of Economics and Business",
    "auth.gr": "Aristotle University of Thessaloniki",
    "panteion.gr": "Panteion University",
    "unipi.gr": "University of Piraeus",
    "uom.gr": "University of Macedonia",
    "uom.edu.gr": "University of Macedonia",
    "upatras.gr": "University of Patras",
    "upnet.gr": "University of Patras",
    "uoi.gr": "University of Ioannina",
    "duth.gr": "Democritus University of Thrace",
    "uoc.gr": "University of Crete",
    "tuc.gr": "Technical University of Crete",
    "uth.gr": "University of Thessaly",
    "aegean.gr": "University of the Aegean",
    "ionio.gr": "Ionian University",
    "hua.gr": "Harokopio University of Athens",
    "uop.gr": "University of the Peloponnese",
    "eap.gr": "Hellenic Open University",
    "uowm.gr": "University of Western Macedonia",
    "ihu.gr": "International Hellenic University",
    "ihu.edu.gr": "International Hellenic University",
    "uniwa.gr": "University of West Attica",
    "hmu.gr": "Hellenic Mediterranean University",
    "aspete.gr": "ASPETE - School of Pedagogical and Technological Education",
}


def university_name_for_email(email: str | None) -> str | None:
    """The university behind an address, or None if the domain is unknown.

    LONGEST MATCH WINS, mirroring universityNameForEmail in the app: a
    'uom.edu.gr' address must not be shadowed by the shorter 'uom.gr' root.

    This is the only trustworthy way to know where somebody studies. The value
    it returns is written at signup from the email in the VERIFIED token, and
    a university sent by a client is ignored - otherwise a patched app could
    claim any institution and the whole point of gating signup on university
    domains would be lost.
    """
    if not email or "@" not in email:
        return None

    domain = email.rsplit("@", 1)[1].strip().lower().rstrip(".")
    if not domain:
        return None

    best_name: str | None = None
    best_length = -1
    for root, name in UNIVERSITY_NAMES.items():
        if domain == root or domain.endswith(f".{root}"):
            if len(root) > best_length:
                best_length = len(root)
                best_name = name
    return best_name
