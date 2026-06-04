# schemate

`schemate` provides a small,
[checkmate](https://mllg.github.io/checkmate/)-first schema DSL for R
data. It can infer schemas from example objects, edit schema documents,
save them as JSON, read them back, and validate new inputs against the
schema.

The package is meant for package authors and pipeline authors who want a
compact R-native schema format without adopting the full JSON Schema
vocabulary. A typical workflow is:

1.  infer a conservative schema with
    [`schema_infer()`](https://hongyuanjia.github.io/schemate/reference/schema_infer.md);
2.  edit it with `schema_*()` authoring verbs;
3.  save it with
    [`schema_write()`](https://hongyuanjia.github.io/schemate/reference/schema-json.md);
4.  read it back with
    [`schema_read()`](https://hongyuanjia.github.io/schemate/reference/schema-json.md);
5.  validate inputs with
    [`schema_validate()`](https://hongyuanjia.github.io/schemate/reference/schema_validate.md).

## Installation

``` r

pak::pak("hongyuanjia/schemate")
```

## Quick Start

The public API uses a single `schema_` prefix and works well in
pipelines. Start from an example object, infer a conservative schema,
then compact it into something easier to edit and review.

``` r

library(schemate)

payload <- list(
  items = list(
    list(id = 1L, owner = list(login = "alice", id = 10L), topics = list("r", "schema")),
    list(id = 2L, owner = list(login = "bob", id = 20L), topics = list("validation"))
  )
)

schema <- payload |>
  schema_infer(keys = "named", arrays = "rest") |>
  schema_compact() |>
  schema_set_desc("$items", "Repository-like result items")

schema |>
  schema_validate(payload, mode = "test")
```

``` R
## [1] TRUE
```

[`schema_validate()`](https://hongyuanjia.github.io/schemate/reference/schema_validate.md)
defaults to assert mode: invalid input raises an error and valid input
is returned invisibly. Other modes are available when you need a message
or a boolean result.

``` r

bad_payload <- payload
bad_payload$items[[1L]]$owner$id <- "bad"

schema |>
  schema_validate(bad_payload, mode = "check", name = "payload")
```

``` R
## [1] "payload$items[[1]]$owner$id: Must be of type 'single integerish value', not 'character'"
```

``` r

schema |>
  schema_validate(bad_payload, mode = "test", name = "payload")
```

``` R
## [1] FALSE
```

## Data Frame Inputs

`schemate` also validates ordinary R objects such as data frames. This
is useful for package-facing input contracts where you want a schema
that can be inferred, edited, saved, and reused.

``` r

scores <- data.frame(
  id = 1:3,
  name = c("alice", "bob", "carol"),
  score = c(9.5, 8.0, 7.5)
)

score_schema <- scores |>
  schema_infer(keys = "required") |>
  schema_replace("$id", schema_check("integerish", any.missing = FALSE)) |>
  schema_replace("$score", schema_check("numeric", lower = 0, upper = 10))

score_schema |>
  schema_validate(scores, mode = "test")
```

``` R
## [1] TRUE
```

``` r

bad_scores <- transform(scores, score = as.character(score))
score_schema |>
  schema_validate(bad_scores, mode = "check", name = "scores")
```

``` R
## [1] "scores$score: Must be of type 'numeric', not 'character'"
```

## JSON Workflow

Schemas are stored as a compact JSON DSL. The DSL is not JSON Schema; it
is a thin representation of checkmate checks, field schemas, local
definitions, and combinators.
[`schema_read()`](https://hongyuanjia.github.io/schemate/reference/schema-json.md)
and
[`schema_write()`](https://hongyuanjia.github.io/schemate/reference/schema-json.md)
require the suggested package `jsonlite`.

``` r

path <- tempfile(fileext = ".json")
schema_write(schema, path)

restored <- schema_read(path)
restored |>
  schema_validate(payload)
```

Example schema files are installed under `inst/extdata`:

``` r

system.file("extdata", "person-schema.json", package = "schemate")
```

## Validation Modes

[`schema_validate()`](https://hongyuanjia.github.io/schemate/reference/schema_validate.md)
supports four modes:

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
validate R objects by calling checkmate checks. It adds a schema
lifecycle around those checks: infer, edit, serialize, read, and
validate.

[`pointblank`](https://rstudio.github.io/pointblank/) is a better fit
for tabular data quality workflows, reporting, and column-oriented
validation plans. `schemate` is deliberately narrower and more
structural: it describes R values, R object names, nested lists,
JSON-like payloads, and package-facing input contracts. It is not a
replacement for [JSON Schema](https://json-schema.org/) or
[`jsonvalidate`](https://docs.ropensci.org/jsonvalidate/), which are
better choices when you need standards-compliant JSON document
validation.

The R validation ecosystem is broad:

- [`validate`](https://cran.r-project.org/package=validate) captures
  data validation rules that can be documented, stored, and applied to
  data sets.
- [`assertr`](https://docs.ropensci.org/assertr/) is designed for
  assertive data checks inside analysis pipelines.
- [`data.validator`](https://appsilon.github.io/data.validator/) focuses
  on dataset validation with reporting.
- [`vetr`](https://cran.r-project.org/package=vetr) provides
  template-based structural checks for R objects.
- [`testthat`](https://testthat.r-lib.org/) is the right home for
  unit-test expectations; `schema_validate(..., mode = "expect")` is
  intended to fit into that style.

## License

The project is released under the terms of MIT License.
