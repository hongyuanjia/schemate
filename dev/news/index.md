# Changelog

## schemate (development version)

### Improvements

- Match S7 base classes in checkmate rules.

## schemate 0.1.1

### Improvements

- Add public
  [`schema_flatten()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_flatten.md)
  for preparing reusable flat schemas before repeated validation.
- Preserve grouped field bindings when predicate-based batch edits
  rewrite every grouped field to structurally equivalent targets.
- Cache fixed
  [`schema_replace_where()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_modify_where.md)
  replacements, including cached flat replacements for `SchemaFlat`
  inputs.
- Cache internal `checkmate` checker lookups.
- Use S7 double dispatch for compact structural comparisons.

## schemate 0.1.0

CRAN release: 2026-06-12

### New

- Added the initial `schema_` API for schema inference, JSON IO,
  editing, flattening, printing, and validation.
- Added a generated standalone distribution workflow on the `standalone`
  branch.
- Added package documentation, vignettes, pkgdown grouping, and example
  schema fixtures.
