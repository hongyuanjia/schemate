
# schemate

`schemate` provides a small, checkmate-first schema DSL for R data. It
can infer schemas from example objects, edit schema documents, save them
as JSON, read them back, and validate new inputs against the schema.

The package is meant for package authors and pipeline authors who want a
compact R-native schema format without adopting the full JSON Schema
vocabulary. A typical workflow is:

1.  infer a conservative schema with `schema_infer()`;
2.  edit it with `schema_*()` authoring verbs;
3.  save it with `schema_write()`;
4.  read it back with `schema_read()`;
5.  validate inputs with `schema_validate()`.

## Installation

``` r
pak::pak("hongyuanjia/schemate")
```

## Quick Start

The public API uses a single `schema_` prefix.

``` r
library(schemate)

person <- list(id = 1L, name = "alice", score = 9.5)
schema <- schema_infer(person)
schema <- schema_set_desc(schema, "$id", "Stable person identifier")

schema_validate(schema, list(id = 2L, name = "bob", score = 10))
```

`schema_validate()` defaults to assert mode: invalid input raises an
error and valid input is returned invisibly. Other modes are available
when you need a message or a boolean result.

``` r
schema_validate(schema, list(id = "bad"), mode = "check", name = "candidate")
```

    ## [1] "candidate$id: Must be of type 'single integerish value', not 'character'"

``` r
schema_validate(schema, list(id = "bad"), mode = "test", name = "candidate")
```

    ## [1] FALSE

## JSON Workflow

Schemas are stored as a compact JSON DSL. The DSL is not JSON Schema; it
is a thin representation of checkmate checks, field schemas, local
definitions, and combinators.

``` r
path <- tempfile(fileext = ".json")
schema_write(schema, path)

restored <- schema_read(path)
schema_validate(restored, person)
```

Example schema files are installed under `inst/extdata`:

``` r
system.file("extdata", "person-schema.json", package = "schemate")
```

## Validation Modes

`schema_validate()` supports four modes:

| Mode     | Return value on success           | Return value on failure    |
|----------|-----------------------------------|----------------------------|
| `assert` | invisibly returns the input       | throws an error            |
| `check`  | `TRUE`                            | diagnostic string          |
| `test`   | `TRUE`                            | `FALSE`                    |
| `expect` | testthat-style expectation object | expectation failure object |

Use `assert` inside application code, `check` when displaying
diagnostics, `test` for control flow, and `expect` in tests.

## Standalone Use

`schemate` also publishes a generated standalone bundle for packages
that want the schema features without depending on `schemate` at
runtime.

``` r
usethis::use_standalone("hongyuanjia/schemate", "schema", ref = "standalone")
```

The standalone branch is generated from the development package. Do not
edit the generated standalone file by hand; update the package source
and regenerate it. The standalone changelog lives in
`tools/standalone/NEWS.md`.

## Relation to Other Tools

`schemate` is closest in spirit to checkmate: schemas ultimately
validate R objects by calling checkmate checks. It is not a replacement
for JSON Schema or `jsonvalidate`, which are better choices when you
need standards-compliant JSON document validation. `schemate` is
deliberately narrower: it describes R values, R object names, nested
lists, and package-facing input contracts.
