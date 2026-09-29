/// A piece of SQL with its bound arguments, built by `FtsFilter`.
///
/// [sql] uses positional `?` placeholders, one per entry of [arguments], in
/// order. Bind the arguments; never splice them into the SQL.
///
/// ```dart
/// final clause = filter.where(search, rowid: 'b.rowid');
/// if (clause != null) {
///   db.select('SELECT * FROM books b WHERE ${clause.sql}', clause.arguments);
/// }
/// ```
///
/// For a driver with other placeholders, or to append the clause after
/// arguments you already have, use [render]. To feed a query builder, use
/// [writeTo].
final class FtsClause {
  FtsClause._(this._fragments, this.arguments, {required this.canRank})
    : assert(_fragments.length == arguments.length + 1, 'fragment mismatch');

  final List<String> _fragments;

  /// The values to bind, in placeholder order.
  final List<String> arguments;

  /// Whether FTS5's `rank`, `bm25()`, `highlight()` and `snippet()` can be
  /// used in a query that selects from the FTS5 table with this clause as its
  /// `WHERE` — that is, whether the clause has a top-level `MATCH`.
  ///
  /// False when every term was too short for a trigram index, so the table is
  /// scanned, and with `FtsCombine.any` when some term is scanned, since a
  /// row may then match without the index. Ranking such a query does not
  /// order anything: SQLite either scores every row 0 or refuses with
  /// "unable to use function ... in the requested context".
  final bool canRank;

  /// The clause with a `?` for each argument.
  String get sql => render((_) => '?');

  /// The clause with each argument's placeholder written by [placeholder],
  /// which receives the argument's zero-based index in [arguments].
  ///
  /// ```dart
  /// clause.render((i) => '?${i + 1}');             // numbered: ?1, ?2...
  /// clause.render((i) => '?${i + 1 + offset}');    // after `offset` others
  /// ```
  String render(String Function(int index) placeholder) {
    final buffer = StringBuffer(_fragments.first);
    for (var i = 0; i < arguments.length; i++) {
      buffer
        ..write(placeholder(i))
        ..write(_fragments[i + 1]);
    }
    return buffer.toString();
  }

  /// Feeds the clause to [sql] and [argument] in order: a run of SQL text,
  /// then an argument, then SQL again, ending on SQL.
  ///
  /// This is how a query builder can emit the clause with its own variables:
  /// `drift_fts5_query` writes each argument as a drift `Variable`.
  void writeTo({
    required void Function(String sql) sql,
    required void Function(String argument) argument,
  }) {
    sql(_fragments.first);
    for (var i = 0; i < arguments.length; i++) {
      argument(arguments[i]);
      sql(_fragments[i + 1]);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FtsClause &&
      other.canRank == canRank &&
      _listEquals(other._fragments, _fragments) &&
      _listEquals(other.arguments, arguments);

  @override
  int get hashCode => Object.hash(
    canRank,
    Object.hashAll(_fragments),
    Object.hashAll(arguments),
  );

  @override
  String toString() => 'FtsClause($sql, $arguments)';
}

/// Assembles an [FtsClause] from SQL text and arguments.
final class FtsClauseBuilder {
  final List<String> _fragments = [];
  final List<String> _arguments = [];
  final StringBuffer _current = StringBuffer();
  bool _canRank = false;

  /// Appends SQL text.
  void sql(String text) => _current.write(text);

  /// Appends a placeholder bound to [value].
  void argument(String value) {
    _fragments.add(_current.toString());
    _current.clear();
    _arguments.add(value);
  }

  /// Appends a whole [clause], arguments included. The result can rank only
  /// if the builder is marked so itself.
  void clause(FtsClause clause) => clause.writeTo(sql: sql, argument: argument);

  /// Records that the clause has a top-level `MATCH`.
  void markRankable() => _canRank = true;

  /// The clause assembled so far.
  FtsClause build() => FtsClause._(
    List.unmodifiable([..._fragments, _current.toString()]),
    List.unmodifiable(_arguments),
    canRank: _canRank,
  );
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
