import 'dart:math';

import 'package:fts5_query/fts5_query.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Runs generated clauses against real FTS5 tables, so the tests check what
/// SQLite does with them rather than only what the SQL looks like.
void main() {
  late Database db;

  setUp(() => db = sqlite3.openInMemory());
  tearDown(() => db.close());

  Set<int> rowids(String sql, List<Object?> arguments) => {
    for (final row in db.select(sql, arguments)) row.columnAt(0) as int,
  };

  /// A `books` table with a trigram index kept current by triggers — the
  /// usual external-content setup.
  void createBooks({String tokenize = 'trigram remove_diacritics 1'}) {
    db.execute('''
      CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, author TEXT);
      CREATE VIRTUAL TABLE books_fts USING fts5(
        title, author, content='books', content_rowid='id',
        tokenize = '$tokenize'
      );
      CREATE TRIGGER books_ai AFTER INSERT ON books BEGIN
        INSERT INTO books_fts (rowid, title, author)
        VALUES (new.id, new.title, new.author);
      END;
    ''');
  }

  void insertBooks(Map<int, (String, String)> books) {
    final insert = db.prepare(
      'INSERT INTO books (id, title, author) VALUES (?, ?, ?)',
    );
    books.forEach((id, book) => insert.execute([id, book.$1, book.$2]));
    insert.close();
  }

  Set<int> search(FtsFilter filter, String input) {
    final clause = filter.where(input, rowid: 'b.id');
    return rowids(
      'SELECT b.id FROM books b'
      '${clause == null ? '' : ' WHERE ${clause.sql}'}',
      clause?.arguments ?? const [],
    );
  }

  group('trigram', () {
    final filter = FtsFilter(table: 'books_fts', columns: ['title', 'author']);

    setUp(() {
      createBooks();
      insertBooks({
        1: ('Harry Potter', 'J. K. Rowling'),
        2: ('Café Crème', 'Émile Zola'),
        3: ('Pi', 'Yann Martel'),
        4: ('ÉCOLE', 'Anon'),
        5: ('100% Pure_Data', r'C:\Temp'),
        6: ('नेपाली कथा', 'लेखक'),
        7: ('C++ Primer', 'Lippman'),
      });
    });

    test('blank input lists everything', () {
      expect(search(filter, '  '), {1, 2, 3, 4, 5, 6, 7});
    });

    test('matches a substring anywhere, ignoring case', () {
      expect(search(filter, 'otte'), {1});
      expect(search(filter, 'OTTE'), {1});
    });

    test('every term must match, across columns', () {
      expect(search(filter, 'potter rowling'), {1});
      expect(search(filter, 'potter zola'), isEmpty);
    });

    test('a short term is found by LIKE, not dropped', () {
      expect(search(filter, 'pi'), {3});
      expect(search(filter, 'PI'), {3});
      expect(search(filter, 'harry pi'), isEmpty);
    });

    test('a short term does not match everything beside a long one', () {
      // In a bare MATCH, "zz" would be ignored and Harry Potter found.
      expect(search(filter, 'potter zz'), isEmpty);
    });

    test('a quoted phrase must appear as written', () {
      expect(search(filter, '"harry potter"'), {1});
      expect(search(filter, '"potter harry"'), isEmpty);
    });

    test('long terms fold accents and Unicode case', () {
      expect(search(filter, 'cafe'), {2});
      expect(search(filter, 'école'), {4});
    });

    test('short terms fold ASCII case only, as documented', () {
      // 'école' found ÉCOLE above; the one-letter 'é' does not.
      expect(search(filter, 'é'), {2});
      expect(search(filter, 'É'), {2, 4});
    });

    test('finds scripts beyond Latin', () {
      expect(search(filter, 'नेपा'), {6});
      expect(search(filter, 'कथा'), {6});
    });

    test('LIKE wildcards in a short term match literally', () {
      expect(search(filter, '%'), {5});
      expect(search(filter, '_'), {5});
      expect(search(filter, r'\'), {5});
    });

    test('FTS5 syntax in the input is searched as text', () {
      expect(search(filter, 'C++'), {7});
      for (final hostile in [
        'AND',
        'OR NOT',
        'NEAR(harry potter)',
        'title:harry',
        '{title} : harry',
        '^harry',
        'harry*',
        '"',
        '"""',
        "'; DROP TABLE books; --",
        'ha\u0000rry',
        '(((',
        ')',
        '-harry',
        '+',
      ]) {
        expect(() => search(filter, hostile), returnsNormally, reason: hostile);
      }
      expect(search(filter, 'ha\u0000rry'), {1});
      expect(db.select('SELECT count(*) FROM books').single.columnAt(0), 7);
    });

    test('searches only the listed columns, long terms and short alike', () {
      final titles = FtsFilter(table: 'books_fts', columns: ['title']);
      expect(search(titles, 'rowling'), isEmpty);
      expect(search(titles, 'potter'), {1});
      expect(search(titles, 'pi'), {3});
      expect(search(titles, 'yann'), isEmpty);
    });

    test('combine any widens with every term', () {
      final any = FtsFilter(
        table: 'books_fts',
        columns: ['title', 'author'],
        combine: FtsCombine.any,
      );
      expect(search(any, 'potter zola'), {1, 2});
      expect(search(any, 'potter pi'), {1, 3});
      expect(search(any, 'pi %'), {3, 5});
    });

    test('condition ranks by relevance when the index is used', () {
      final clause = filter.condition('potter')!;
      expect(clause.canRank, isTrue);
      final rows = db.select(
        'SELECT rowid, bm25(books_fts) FROM books_fts '
        'WHERE ${clause.sql} ORDER BY rank',
        clause.arguments,
      );
      expect(rows.map((r) => r.columnAt(0)), [1]);
    });

    test('a mixed condition can still rank and highlight', () {
      final clause = filter.condition('potter ow')!;
      expect(clause.canRank, isTrue);
      final rows = db.select(
        "SELECT highlight(books_fts, 0, '[', ']') FROM books_fts "
        'WHERE ${clause.sql} ORDER BY rank',
        clause.arguments,
      );
      expect(rows.single.columnAt(0), 'Harry [Potter]');
    });

    test('canRank is false when there is no relevance to rank by', () {
      final any = FtsFilter(
        table: 'books_fts',
        columns: ['title', 'author'],
        combine: FtsCombine.any,
      );
      for (final (f, input) in [(filter, 'pi'), (any, 'potter pi')]) {
        final clause = f.condition(input)!;
        expect(clause.canRank, isFalse, reason: input);
        // SQLite either refuses bm25() here or scores every row 0.
        try {
          final scores = db.select(
            'SELECT bm25(books_fts) FROM books_fts WHERE ${clause.sql}',
            clause.arguments,
          );
          expect(
            scores.map((r) => r.columnAt(0)),
            everyElement(0),
            reason: input,
          );
        } on SqliteException catch (e) {
          expect(e.message, contains('unable to use function'), reason: input);
        }
      }
    });

    test('the condition ANDs safely into a larger WHERE', () {
      final any = FtsFilter(
        table: 'books_fts',
        columns: ['title', 'author'],
        combine: FtsCombine.any,
      );
      final clause = any.condition('potter pi')!;
      final found = rowids(
        'SELECT rowid FROM books_fts WHERE rowid <> 3 AND ${clause.sql}',
        clause.arguments,
      );
      expect(found, {1});
    });

    test('numbered placeholders bind after other arguments', () {
      final clause = filter.where('potter ow', rowid: 'b.id')!;
      final found = rowids(
        'SELECT b.id FROM books b WHERE b.id > ?1 AND '
        '${clause.render((i) => '?${i + 2}')}',
        [0, ...clause.arguments],
      );
      expect(found, {1});
    });

    test('short and long terms agree on ASCII text', () {
      // Every substring of every title, of every length, run through the
      // filter must find exactly the rows a plain substring test finds —
      // whether it went to the trigram index or to LIKE.
      final random = Random(42);
      const alphabet = 'abcdeABCDE .-';
      String word() => String.fromCharCodes(
        List.generate(
          4 + random.nextInt(8),
          (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
        ),
      );

      db.execute('DELETE FROM books');
      db.execute("INSERT INTO books_fts (books_fts) VALUES ('rebuild')");
      final corpus = {for (var id = 1; id <= 60; id++) id: (word(), word())};
      insertBooks(corpus);

      final quoted = FtsFilter(
        table: 'books_fts',
        columns: ['title', 'author'],
        quotedPhrases: false,
      );
      var checked = 0;
      for (final (title, _) in corpus.values.take(20)) {
        for (var start = 0; start < title.length; start++) {
          for (var length = 1; length <= 5; length++) {
            if (start + length > title.length) break;
            final term = title.substring(start, start + length).trim();
            if (term.isEmpty || term.contains(' ')) continue;
            final needle = term.toLowerCase();
            final expected = {
              for (final MapEntry(key: id, value: (t, a)) in corpus.entries)
                if (t.toLowerCase().contains(needle) ||
                    a.toLowerCase().contains(needle))
                  id,
            };
            expect(search(quoted, term), expected, reason: term);
            checked++;
          }
        }
      }
      expect(checked, greaterThan(200));
    });
  });

  group('trigram case_sensitive', () {
    test('short terms are case-sensitive too', () {
      createBooks(tokenize: 'trigram case_sensitive 1');
      insertBooks({1: ('Harry', ''), 2: ('harry', ''), 3: ('a*b', '')});
      final filter = FtsFilter(
        table: 'books_fts',
        columns: ['title', 'author'],
        tokenizer: const FtsTokenizer.trigram(caseSensitive: true),
      );
      expect(search(filter, 'Har'), {1});
      expect(search(filter, 'Ha'), {1});
      expect(search(filter, 'ha'), {2});
      expect(search(filter, '*'), {3});
      expect(search(filter, '?'), isEmpty);
    });
  });

  group('word tokenizer', () {
    setUp(() {
      createBooks(tokenize: 'unicode61 remove_diacritics 2');
      insertBooks({
        1: ('Harry Potter and the Stone', 'Rowling'),
        2: ('The Potting Shed', 'Greene'),
        3: ('A Tale of Two Cities', 'Dickens'),
      });
    });

    FtsFilter words(FtsPrefix prefix) => FtsFilter(
      table: 'books_fts',
      columns: ['title', 'author'],
      tokenizer: FtsTokenizer.words(prefix: prefix),
    );

    test('matches whole words', () {
      expect(search(words(FtsPrefix.none), 'potter'), {1});
      expect(search(words(FtsPrefix.none), 'pot'), isEmpty);
    });

    test('prefix last completes the word being typed', () {
      expect(search(words(FtsPrefix.last), 'pot'), {1, 2});
      expect(search(words(FtsPrefix.last), 'harry pot'), {1});
      expect(search(words(FtsPrefix.last), 'har pot'), isEmpty);
    });

    test('prefix all completes every word', () {
      expect(search(words(FtsPrefix.all), 'har pot'), {1});
    });

    test('a one-letter word goes through the index', () {
      expect(search(words(FtsPrefix.none), 'a'), {3});
    });

    test('a quoted phrase is matched exactly', () {
      expect(search(words(FtsPrefix.all), '"two cities"'), {3});
      expect(search(words(FtsPrefix.all), '"two cit"'), isEmpty);
    });
  });

  group('table shapes', () {
    test('a plain FTS5 table works through condition', () {
      db.execute(
        "CREATE VIRTUAL TABLE notes USING fts5(body, tokenize='trigram')",
      );
      db.execute("INSERT INTO notes (body) VALUES ('buy milk'), ('pi day')");
      final filter = FtsFilter(table: 'notes', columns: ['body']);
      for (final (input, expected) in [
        ('milk', {1}),
        ('pi', {2}),
      ]) {
        final clause = filter.condition(input)!;
        expect(
          rowids(
            'SELECT rowid FROM notes WHERE ${clause.sql}',
            clause.arguments,
          ),
          expected,
        );
      }
    });

    test('quoted and schema-qualified names work', () {
      db.execute(
        'CREATE VIRTUAL TABLE "search index" USING '
        "fts5(\"the title\", tokenize='trigram')",
      );
      db.execute('INSERT INTO "search index" ("the title") VALUES (\'Harry\')');
      final filter = FtsFilter(
        table: 'main."search index"',
        columns: ['"the title"'],
      );
      for (final input in ['harry', 'ha']) {
        final clause = filter.subquery(input)!;
        expect(rowids(clause.sql, clause.arguments), {1}, reason: input);
      }
    });

    test('a contentless table cannot answer short terms, as documented', () {
      db.execute(
        "CREATE VIRTUAL TABLE c USING fts5(body, content='', "
        "tokenize='trigram')",
      );
      db.execute("INSERT INTO c (rowid, body) VALUES (1, 'Harry')");
      final filter = FtsFilter(table: 'c', columns: ['body']);
      Set<int> find(String input) {
        final clause = filter.subquery(input)!;
        return rowids(clause.sql, clause.arguments);
      }

      expect(find('harry'), {1});
      expect(find('ha'), isEmpty);
    });
  });
}
