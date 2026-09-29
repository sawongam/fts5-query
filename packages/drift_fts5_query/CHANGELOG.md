## 1.0.0

- Initial release.
- `FtsFilter.matches(search, rowid: expression)`: a typed `Expression<bool>`
  for drift's query builder; `TRUE` for a blank search.
- `FtsClause.variables` for `customSelect`, and `FtsClause.toExpression` to
  embed any clause in the query builder.
