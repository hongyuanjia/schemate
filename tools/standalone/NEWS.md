# Standalone Changelog

## 2026-06-14
- Add file-level copyright and SPDX license metadata to the generated bundle.

## 2026-06-13
- Match S7 base classes in checkmate rules.

## 2026-06-06
- Rename missing-target controls from `error_if_missing` to
  `missing = "error"` / `missing = "ignore"` across schema deletion and
  predicate-based batch edit helpers.
- Add public `schema_flatten()` for reusing flattened schemas across repeated
  validation calls.
- Speed up exact field validation for wide schemas and reduce key-copying
  overhead while compacting grouped fields.
- Speed up schema compaction's structural equality checks by comparing S7 slots
  directly and normalizing `keys` rules consistently with `check_names()`.
- Reduce intermediate S7 object construction while compiling grouped fields and
  compacting container field groups.
- Preserve grouped field bindings when predicate-based batch edits rewrite every
  grouped field to structurally equivalent targets.
- Cache fixed `schema_replace_where()` replacements, including cached flat
  replacements for `SchemaFlat` inputs.
- Run standalone local verification against a temporary copy of the full package
  test suite, then remove the copied tests.
- Use S7 double dispatch for compact structural comparisons.

## 2026-06-05
- Treat `fields`, `patterns`, and `positions` as optional child validators
  during schema validation; use `keys` and `check` rules for required keys and
  length constraints.

## 2026-06-04
- Add schema path query and batch edit helpers: `schema_paths()`,
  `schema_find()`, `schema_modify_where()`, `schema_replace_where()`,
  `schema_where_path()`, and `schema_where_check()`.
- Cleanup roxygen2 documentation comments when bundling.
- Share standalone DESCRIPTION generation logic between generation and local
  tests, while preserving the source package DESCRIPTION.

## 2026-06-03

- Initial standalone schema bundle for `schemate`.
- Includes schema inference, schema editing, JSON reading/writing, and schema
  validation in a single `standalone-schema.R` file.
- Rename non-exported functions with consistent prefixes.
- Add `patterns` and `rest` schema support, including `schema_set_rest()` and
  `schema_del_rest()`.
- Add `positions` schema support for unnamed list prefix validation, including
  `schema_add_position()` and `schema_del_position()`.
- Add `schema_infer(arrays = "rest")` and `schema_compact()` for compacting
  inferred JSON array schemas.
- Allow logical field edit paths to traverse grouped schema fields.
- Allow `groups` entries to contain complete schema nodes for JSON round-trips.
- Treat `jsonlite` as optional; JSON IO requires it at runtime, while printing
  has a base R fallback.
- Refactor schema compaction internals to use S7 dispatch.
- Remove the unimplemented `defs` argument from `schema_compact()`.
- Expand package documentation and examples for nested objects, data frames,
  rest schemas, positions, and validation diagnostics.
- Narrow the standalone changelog pre-commit reminder to source and standalone
  tooling changes.
