# schemate standalone bundle

This branch contains the generated standalone schema bundle from `hongyuanjia/schemate`.

Use it when another R package needs schemate's schema construction, validation, query, and edit helpers without depending on the full development tree.

## Install

```r
usethis::use_standalone("hongyuanjia/schemate", "schema", ref = "standalone")
```

This copies `R/standalone-schema.R` into your package.

## Requirements

- Required packages: checkmate (>= 2.0.0), S7.
- Optional package: jsonlite.

Declare these dependencies in the package that vendors the standalone file.

## Example

```r
schema <- schema_compact(schema_infer(list(
    id = 1L,
    owner = list(login = "alice")
)))

schema_validate(schema, list(
    id = 2L,
    owner = list(login = "bob")
))
```

## Maintenance

This bundle was generated from source commit `7d11f6009a0d2f89b6aa66543de18ed1cb1adc9b`.

Do not edit files on this branch by hand. Make changes on the main branch, update the standalone generator or source files, and regenerate the branch.
