// An example prints what it finds.
// ignore_for_file: avoid_print

// Searches a small catalogue the way a search box would, with the `sqlite3`
// package. The same clauses work with sqflite: pass `clause.sql` and
// `clause.arguments` to `rawQuery`.
import 'package:fts5_query/fts5_query.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.openInMemory()
    ..execute('''
      CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, author TEXT);

      -- A trigram index finds any substring: "otte" finds "Potter".
      CREATE VIRTUAL TABLE books_fts USING fts5(
        title, author, content = 'books', content_rowid = 'id',
        tokenize = 'trigram remove_diacritics 1'
      );
      CREATE TRIGGER books_ai AFTER INSERT ON books BEGIN
        INSERT INTO books_fts (rowid, title, author)
        VALUES (new.id, new.title, new.author);
      END;

      INSERT INTO books (title, author) VALUES
        ('Harry Potter and the Philosopher''s Stone', 'J. K. Rowling'),
        ('Life of Pi', 'Yann Martel'),
        ('Thérèse Raquin', 'Émile Zola');
    ''');

  // Configure once per FTS5 table.
  final bookSearch = FtsFilter(
    table: 'books_fts',
    columns: ['title', 'author'],
  );

  // Filter another query by the search: `b.id IN (SELECT rowid ...)`.
  for (final input in ['potter rowling', 'pi', 'therese', '"of pi"', '']) {
    final clause = bookSearch.where(input, rowid: 'b.id');
    final rows = db.select(
      'SELECT b.title FROM books b'
      '${clause == null ? '' : ' WHERE ${clause.sql}'}'
      ' ORDER BY b.title',
      clause?.arguments ?? const [],
    );
    print(
      '${input.isEmpty ? '(blank)' : input} → '
      '${rows.map((r) => r['title']).join('; ')}',
    );
  }

  // Or query the index itself, to rank and highlight.
  final clause = bookSearch.condition('stone')!;
  final ranked = db.select(
    "SELECT highlight(books_fts, 0, '[', ']') AS hit FROM books_fts "
    'WHERE ${clause.sql}${clause.canRank ? ' ORDER BY rank' : ''}',
    clause.arguments,
  );
  print('stone → ${ranked.single['hit']}');

  db.close();
}
