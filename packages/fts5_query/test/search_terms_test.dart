import 'package:fts5_query/fts5_query.dart';
import 'package:test/test.dart';

void main() {
  group('parseSearch', () {
    List<String> texts(String input, {bool quotedPhrases = true}) => [
      for (final term in parseSearch(input, quotedPhrases: quotedPhrases))
        term.text,
    ];

    test('returns nothing for blank input', () {
      expect(parseSearch(''), isEmpty);
      expect(parseSearch('   \t\n '), isEmpty);
      expect(parseSearch('""'), isEmpty);
      expect(parseSearch('"   "'), isEmpty);
    });

    test('splits on any Unicode whitespace', () {
      // No-break space, ideographic space, em space, newline.
      expect(texts('harry potter　rowling one\ntwo'), [
        'harry',
        'potter',
        'rowling',
        'one',
        'two',
      ]);
    });

    test('keeps a quoted phrase together and marks it quoted', () {
      expect(parseSearch('"harry potter" rowling'), [
        const SearchTerm('harry potter', quoted: true),
        const SearchTerm('rowling'),
      ]);
    });

    test('collapses whitespace inside a phrase', () {
      expect(texts('"  harry \t  potter "'), ['harry potter']);
    });

    test('runs an unclosed quote to the end of the input', () {
      expect(parseSearch('rowling "harry pot'), [
        const SearchTerm('rowling'),
        const SearchTerm('harry pot', quoted: true),
      ]);
    });

    test('a quote inside a word starts a phrase', () {
      expect(parseSearch('ab"cd ef"gh'), [
        const SearchTerm('ab'),
        const SearchTerm('cd ef', quoted: true),
        const SearchTerm('gh'),
      ]);
    });

    test('treats quotes as text when quotedPhrases is off', () {
      expect(texts('"harry potter"', quotedPhrases: false), [
        '"harry',
        'potter"',
      ]);
    });

    test('removes NUL characters', () {
      expect(texts('ha\u0000rry \u0000'), ['harry']);
    });

    test('drops repeated terms, keeping the first', () {
      expect(texts('potter harry potter "potter"'), [
        'potter',
        'harry',
        'potter',
      ]);
      expect(parseSearch('potter "potter"').last.quoted, isTrue);
    });

    test('stops at maxTerms', () {
      expect(parseSearch('a b c d', maxTerms: 2).map((t) => t.text), [
        'a',
        'b',
      ]);
      expect(parseSearch('a ' * 100), hasLength(1));
      expect(
        parseSearch(List.generate(100, (i) => 'w$i').join(' ')),
        hasLength(defaultMaxTerms),
      );
    });

    test('rejects a maxTerms below one', () {
      expect(() => parseSearch('a', maxTerms: 0), throwsArgumentError);
    });

    test('returns an unmodifiable list', () {
      expect(
        () => parseSearch('a').add(const SearchTerm('b')),
        throwsUnsupportedError,
      );
    });
  });

  group('SearchTerm', () {
    test('length counts code points, not UTF-16 units', () {
      expect(const SearchTerm('ab').length, 2);
      expect(const SearchTerm('😀').length, 1);
      expect(const SearchTerm('नेपाल').length, 5);
    });

    test('has value equality', () {
      expect(const SearchTerm('a'), const SearchTerm('a'));
      expect(const SearchTerm('a'), isNot(const SearchTerm('a', quoted: true)));
      expect(const SearchTerm('a').hashCode, const SearchTerm('a').hashCode);
    });

    test('toString shows whether it was quoted', () {
      expect(const SearchTerm('a').toString(), 'SearchTerm(a)');
      expect(
        const SearchTerm('a b', quoted: true).toString(),
        'SearchTerm("a b")',
      );
    });
  });
}
