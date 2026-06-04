# Standalone Changelog

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
