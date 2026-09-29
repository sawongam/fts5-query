# fts5_query

[![pub package](https://img.shields.io/pub/v/fts5_query.svg)](https://pub.dev/packages/fts5_query)
[![CI](https://github.com/sawongam/fts5-query/actions/workflows/ci.yaml/badge.svg)](https://github.com/sawongam/fts5-query/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Turn what a user types into a search box into a **safe SQLite FTS5 filter**.

```dart
final bookSearch = FtsFilter(table: 'books_fts', columns: ['title', 'author']);

final clause = bookSearch.where(searchBoxText, rowid: 'b.id');
db.select(
  'SELECT * FROM books b${clause == null ? '' : ' WHERE ${clause.sql}'}',
  clause?.arguments ?? const [],
);
```

Pure Dart with no dependencies, so it works with
[`sqlite3`](https://pub.dev/packages/sqlite3),
[`sqflite`](https://pub.dev/packages/sqflite),
[`sqflite_common_ffi`](https://pub.dev/packages/sqflite_common_ffi) or anything
else that runs SQL. **Using drift?** Add
[`drift_fts5_query`](https://pub.dev/packages/drift_fts5_query) and write
`select(books)..where((b) => bookSearch.matches(input, rowid: b.id))`.

## Why not just `MATCH ?`

Passing the user's text straight to `MATCH` looks right, but FTS5 parses it as
a query language:

| The user types | Raw `MATCH ?` | `fts5_query` |
| --- | --- | --- |
| `c++` | syntax error | finds "C++ Primer" |
| `"unclosed` | `unterminated string` | a phrase still being typed |
| `rock AND` / `NEAR(` / `title:x` | syntax errors, or a different query | searched as text |
| `pi` on a trigram table | matches **nothing**; beside another term it is silently **ignored** | found with `LIKE` |
| `100%` on the `LIKE` fallback | `%` is a wildcard | matches a literal `%` |
| A pasted 10,000-word essay | a 10,000-term query | capped at 32 terms |
| A NUL character | cuts the query short | removed |

`fts5_query` quotes every term as an FTS5 string, escapes every `LIKE`
pattern, binds everything as an argument and checks the identifiers you give
it, so no input can break the query or change its meaning.

## Features

- **Search-box semantics.** Every word must appear, in any column, in any
  order: `potter rowling` finds the book whose title has one word and whose
  author has the other. `"harry potter"` in quotes is one phrase.
- **Trigram tables done right.** Terms of three or more characters use the
  index; shorter ones fall back to `LIKE` over the same columns, so `pi` and
  `C#` still find something.
- **Word tokenizers too.** `unicode61`, `porter` and `ascii` tables get prefix
  matching for the word being typed (`harry pot` → "Harry Potter").
- **Match all or any** of the terms.
- **Ranking.** Query the index directly and order by `rank`, or call
  `highlight()` and `snippet()`.
- **Any placeholder style.** `?`, `?1`, or whatever your driver needs.
- **Tested against real SQLite**, including a randomised check that short
  terms (through `LIKE`) and long ones (through the index) find the same rows.

## Usage

### 1. Create the index

An FTS5 table that stores its text — a normal one or, as here, an
external-content one kept current by triggers:

```sql
CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, author TEXT);

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

The `trigram` tokenizer needs SQLite 3.34 or later; `remove_diacritics` in a
trigram table needs 3.45.

### 2. Describe it once

```dart
final bookSearch = FtsFilter(
  table: 'books_fts',
  columns: ['title', 'author'],
  // tokenizer: FtsTokenizer.trigram(),   // the default
  // combine: FtsCombine.all,             // the default
);
```

### 3. Filter with it

Three shapes, from the most common to the most specific:

```dart
// A condition on your own table's rows.
bookSearch.where(input, rowid: 'b.id');
// b.id IN (SELECT rowid FROM books_fts WHERE books_fts MATCH ?)

// The matching rowids, to join on.
bookSearch.subquery(input);
// SELECT rowid FROM books_fts WHERE books_fts MATCH ?

// The bare condition, to query the index itself.
bookSearch.condition(input);
// books_fts MATCH ?
```

Each returns an `FtsClause` with `sql` and `arguments`, or **`null` when the
input is blank**, so an empty search box adds no condition and lists every
row.

With sqflite:

```dart
final clause = bookSearch.where(input, rowid: 'b.id');
final rows = await db.rawQuery(
  'SELECT * FROM books b${clause == null ? '' : ' WHERE ${clause.sql}'}',
  clause?.arguments,
);
```

### Ranking and highlighting

```dart
final clause = bookSearch.condition(input);
if (clause != null) {
  db.select(
    "SELECT rowid, highlight(books_fts, 0, '<b>', '</b>') AS title "
    'FROM books_fts WHERE ${clause.sql}'
    '${clause.canRank ? ' ORDER BY rank' : ''}',
    clause.arguments,
  );
}
```

`canRank` is false when every term was too short for the trigram index, since
there is then no relevance to rank by.

### Word tokenizers

```dart
final articleSearch = FtsFilter(
  table: 'articles_fts', // tokenize = 'porter unicode61'
  columns: ['headline', 'body'],
  tokenizer: FtsTokenizer.words(prefix: FtsPrefix.last),
);
// "climate chan" → {"headline" "body"} : ("climate" AND "chan"*)
```

`FtsPrefix.none` matches whole words only, `last` (the default) completes the
word being typed, and `all` completes every word. A phrase in quotes is always
matched exactly.

### Other placeholders, other arguments

```dart
final clause = bookSearch.where(input, rowid: 'b.id')!;
db.select(
  'SELECT * FROM books b WHERE b.year > ?1 AND '
  '${clause.render((i) => '?${i + 2}')}',
  [1990, ...clause.arguments],
);
```

`clause.writeTo(sql: ..., argument: ...)` streams the clause to a query builder
piece by piece. `drift_fts5_query` is built on it.

### Building blocks

`parseSearch` splits input into terms. `Fts5Syntax.phrase`, `.likeContains`,
`.globContains` and `.columnFilter` escape values for hand-written queries.

## Configuration

| `FtsFilter(...)` | Default | |
| --- | --- | --- |
| `table` | required | The FTS5 table; may be `schema.table` |
| `columns` | required | Columns to search. Both the index and the fallback are restricted to them |
| `tokenizer` | `FtsTokenizer.trigram()` | Mirror the table's `tokenize` option (below) |
| `combine` | `FtsCombine.all` | `any` to match rows containing at least one term |
| `quotedPhrases` | `true` | `false` treats `"` as an ordinary character |
| `maxTerms` | `32` | Terms beyond this are ignored |

| Table created with `tokenize =` | Use |
| --- | --- |
| `'trigram'`, `'trigram remove_diacritics 1'` | `FtsTokenizer.trigram()` |
| `'trigram case_sensitive 1'` | `FtsTokenizer.trigram(caseSensitive: true)` |
| `'unicode61'`, `'porter'`, `'ascii'`, default | `FtsTokenizer.words()` |

## Things to know

- **Identifiers are trusted.** `table`, `columns` and `rowid` are written into
  the SQL. They are checked to be plain or double-quoted identifiers, and
  anything else throws an `ArgumentError`, but they must come from your code,
  **never from user input**. Only the search text is untrusted, and it is
  always bound.
- **Contentless tables** (`content=''`) have no stored text, so on a trigram
  table a one- or two-character term finds nothing. Use a normal or
  external-content table if short terms matter.
- **Short terms compare more strictly than long ones.** The fallback uses
  SQLite's `LIKE`, which folds case for ASCII letters only and ignores
  `remove_diacritics`: `école` finds "ÉCOLE" through the index, but the
  one-letter `é` does not find "É". ASCII text behaves identically either way.
  On a `case_sensitive 1` table the fallback uses `GLOB` and is case-sensitive
  too. `PRAGMA case_sensitive_like` affects the fallback.
- **The fallback scans.** A term shorter than three characters reads every row
  of the index, which is fast for the tens of thousands of rows a local app
  holds. Terms of three or more characters always use the index.

## License

MIT
