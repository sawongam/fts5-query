/// Checks that SQL names passed to `FtsFilter` are identifiers, so a value
/// that reached it from user input fails loudly instead of becoming SQL.
///
/// Accepted: bare identifiers (`titles_fts`, `t`, `rowid`) and double-quoted
/// ones (`"search index"`, with inner quotes doubled), joined by dots where a
/// qualified name is allowed (`main.titles_fts`, `t.rowid`). Bracketed and
/// backquoted names are rejected — write them in double quotes.
library;

final RegExp _part = RegExp(
  r'(?:[A-Za-z_\u0080-￿][A-Za-z0-9_$\u0080-￿]*|"(?:[^"]|"")+")',
);

final Map<int, RegExp> _qualified = {};

/// Returns [value] if it is an identifier of at most [maxParts] dotted parts,
/// otherwise throws an [ArgumentError] naming the parameter [name].
String checkIdentifier(String value, String name, {int maxParts = 1}) {
  final pattern = _qualified.putIfAbsent(
    maxParts,
    () =>
        RegExp('^${_part.pattern}(?:\\.${_part.pattern}){0,${maxParts - 1}}\$'),
  );
  if (!pattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      name,
      maxParts == 1
          ? 'must be a SQL identifier: a bare name or a "double-quoted" one'
          : 'must be a SQL identifier, optionally qualified with dots '
                '(at most $maxParts parts)',
    );
  }
  return value;
}

/// The last dotted part of the checked identifier [value]: `titles_fts` for
/// `main.titles_fts`.
String lastPart(String value) {
  final parts = _splitParts(value);
  return parts.last;
}

/// The name an identifier stands for: [value] unquoted, if it was quoted.
String unquote(String value) {
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    return value.substring(1, value.length - 1).replaceAll('""', '"');
  }
  return value;
}

List<String> _splitParts(String value) => [
  for (final match in _part.allMatches(value)) match[0]!,
];
