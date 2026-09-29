## 1.0.0

- Initial release.
- `FtsFilter`: turns search-box text into a `WHERE` condition (`where`), a
  rowid subquery (`subquery`) or a bare condition over the FTS5 table
  (`condition`), with every value bound as an argument.
- Trigram tables: terms shorter than the index can hold fall back to `LIKE`,
  or to `GLOB` on `case_sensitive 1` tables.
- Word tables (`unicode61`, `porter`, `ascii`): prefix matching with
  `FtsPrefix.none`, `last` or `all`.
- `FtsCombine.all` / `any`, quoted phrases, a cap on the number of terms.
- Identifiers are validated; malformed ones throw `ArgumentError`.
- `FtsClause.render` for numbered placeholders, `writeTo` for query builders,
  `canRank` for relevance ordering.
- `parseSearch` and `Fts5Syntax` as standalone building blocks.
