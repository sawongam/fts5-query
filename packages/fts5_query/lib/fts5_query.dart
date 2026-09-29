/// Turn search-box text into a safe SQLite FTS5 filter: quoted phrases, a
/// `LIKE` fallback for terms too short for a trigram index, and bound
/// arguments throughout.
///
/// Start with `FtsFilter`.
library;

export 'src/search_terms.dart';
