# schemate (development version)

## Improvements

- Preserve grouped field bindings when predicate-based batch edits rewrite every
  grouped field to structurally equivalent targets.
- Cache internal `checkmate` checker lookups.

# schemate 0.1.0

## New

- Added the initial `schema_` API for schema inference, JSON IO, editing,
  flattening, printing, and validation.
- Added a generated standalone distribution workflow on the `standalone` branch.
- Added package documentation, vignettes, pkgdown grouping, and example schema
  fixtures.
