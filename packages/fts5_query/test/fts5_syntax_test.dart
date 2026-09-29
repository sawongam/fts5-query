import 'package:fts5_query/fts5_query.dart';
import 'package:test/test.dart';

void main() {
  group('Fts5Syntax', () {
    test('phrase quotes and doubles inner quotes', () {
      expect(Fts5Syntax.phrase('potter'), '"potter"');
      expect(Fts5Syntax.phrase('say "hi"'), '"say ""hi"""');
      expect(Fts5Syntax.phrase('a OR b NEAR(c) *:^'), '"a OR b NEAR(c) *:^"');
    });

    test('prefixPhrase adds the prefix star outside the quotes', () {
      expect(Fts5Syntax.prefixPhrase('pot'), '"pot"*');
    });

    test('columnFilter quotes every column name', () {
      expect(
        Fts5Syntax.columnFilter(['title', 'author']),
        '{"title" "author"} : ',
      );
      expect(Fts5Syntax.columnFilter(['a"b']), '{"a""b"} : ');
    });

    test('escapeLike escapes the wildcards and the escape character', () {
      expect(Fts5Syntax.escapeLike(r'100% a_b c\d'), r'100\% a\_b c\\d');
      expect(Fts5Syntax.likeContains('5%'), r'%5\%%');
    });

    test('escapeGlob brackets the metacharacters', () {
      expect(Fts5Syntax.escapeGlob('a*b?c[d]'), 'a[*]b[?]c[[]d]');
      expect(Fts5Syntax.globContains('*'), '*[*]*');
    });
  });
}
