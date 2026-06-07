# Validate input against a schema

`schema_validate()` validates an R object against a `SchemaDoc`,
`SchemaFlat`, or flattened schema node. When validating many inputs
against the same schema, flatten it once with
[`schema_flatten()`](https://hongyuanjia.github.io/schemate/reference/schema_flatten.md)
and reuse the flattened schema.

## Usage

``` r
schema_validate(schema, x, mode = "assert", name = NULL, ...)
```

## Arguments

- schema:

  A `SchemaDoc`, `SchemaFlat`, or flattened schema node.

- x:

  Input object to validate.

- mode:

  One of `"assert"`, `"check"`, `"test"`, or `"expect"`.

- name:

  Optional display name used in validation messages.

- ...:

  Reserved for future extension.

## Value

In `"assert"` mode, invisibly returns `x` or throws an error. In
`"check"` mode, returns `TRUE` or a diagnostic string. In `"test"` mode,
returns `TRUE` or `FALSE`. In `"expect"` mode, returns a testthat-style
expectation object.

## Examples

``` r
schema <- schema_doc(list(
    check = list(kind = "list"),
    fields = list(id = list(check = list(kind = "int", lower = 1)))
))
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "fields": {
#>     "id": {
#>       "check": {
#>         "kind": "int",
#>         "lower": 1
#>       }
#>     }
#>   }
#> }

schema_validate(schema, list(id = 1L), mode = "test")
#> [1] TRUE
schema_validate(schema, list(id = 0L), mode = "check", name = "payload")
#> [1] "payload$id: Element 1 is not >= 1"

flat <- schema_flatten(schema)
schema_validate(flat, list(id = 2L), mode = "test")
#> [1] TRUE
```
