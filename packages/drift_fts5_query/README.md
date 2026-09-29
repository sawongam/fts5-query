# drift_fts5_query

[![pub package](https://img.shields.io/pub/v/drift_fts5_query.svg)](https://pub.dev/packages/drift_fts5_query)
[![CI](https://github.com/sawongam/fts5-query/actions/workflows/ci.yaml/badge.svg)](https://github.com/sawongam/fts5-query/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Filter any [drift](https://pub.dev/packages/drift) query by what a user typed
into a search box, through an SQLite FTS5 index:

```dart
final bookSearch = FtsFilter(table: 'books_fts', columns: ['title', 'author']);

final books = await (select(db.books)
      ..where((b) => bookSearch.matches(searchBoxText, rowid: b.id)))
    .get();
```

This is the drift integration for
[`fts5_query`](https://pub.dev/packages/fts5_query). That package's README
explains what the filter does: it quotes every term so user input can never
break the query, requires every word to match in any column, and falls back
to `LIKE` for terms too short for a trigram index. This package re-exports
it, so one import is enough.

## Setup

```yaml
dependencies:
  drift_fts5_query: ^1.0.0
```

Declare the index in a `.drift` file beside your tables, with triggers that
keep it current:

```sql
-- books.drift
CREATE VIRTUAL TABLE books_fts USING fts5(
  title, author,
  content = 'books', content_rowid = 'id',
  tokenize = 'trigram remove_diacritics 1'
);

CREATE TRIGGER books_ai AFTER INSERT ON books BEGIN
  INSERT INTO books_fts (rowid, title, author)
  VALUES (new.id, new.title, new.author);
END;
-- ...plus AFTER UPDATE and AFTER DELETE triggers.
```

Tell drift's analyzer about FTS5 in `build.yaml`:

```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          sql:
            dialect: sqlite
            options:
              modules: [fts5]
```

## Query builder

`matches` is a typed `Expression<bool>`, so it composes with everything else:

```dart
final query = select(books)
  ..where((b) => bookSearch.matches(input, rowid: b.id) & b.archived.not())
  ..orderBy([(b) => OrderingTerm(expression: b.title)]);
```

- **A blank search is `TRUE`**, so the query lists every row with no branch at
  the call site.
- `rowid` is a drift expression, so table aliases and joins work:
  `rowid: aliased.id`, or `rowid: books.rowId` for a table without an integer
  primary key.
- **Streams**: `watch()` re-runs when the queried table changes. With the usual
  triggers, the index changes only when that table does. If the index can
  change on its own, pass `watchedTables: [booksFts]`.

## Custom SQL

For `customSelect`, `FtsClause.variables` gives the arguments as drift
`Variable`s:

```dart
final clause = bookSearch.where(input, rowid: 'b.id');
final rows = await customSelect(
  'SELECT b.* FROM books b${clause == null ? '' : ' WHERE ${clause.sql}'}',
  variables: clause?.variables ?? const [],
  readsFrom: {books},
).get();
```

To rank by relevance, query the index itself:

```dart
final clause = bookSearch.condition(input);
if (clause != null) {
  final rows = await customSelect(
    "SELECT rowid, highlight(books_fts, 0, '<b>', '</b>') AS hit "
    'FROM books_fts WHERE ${clause.sql}'
    '${clause.canRank ? ' ORDER BY rank' : ''}',
    variables: clause.variables,
    readsFrom: {booksFts},
  ).get();
}
```

`clause.toExpression<bool>()` embeds any `FtsClause` in the query builder.

## Things to know

Everything in `fts5_query`'s
[Things to know](https://pub.dev/packages/fts5_query#things-to-know) applies.
In short: `table`, `columns` and a string `rowid` are trusted identifiers,
never user input. Short terms need a table that stores its text, not a
contentless one. And short terms fold case for ASCII only.

Drift on the web runs `sqlite3.wasm`, which includes FTS5 and the trigram
tokenizer.

## License

MIT
