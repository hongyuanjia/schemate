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
