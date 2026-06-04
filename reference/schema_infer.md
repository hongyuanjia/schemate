# Infer a conservative schema from example data

`schema_infer()` builds a `SchemaDoc` from example data using
conservative, structural inference only. It infers base/container check
kinds and nested field structure, but does not guess higher-level
authoring constructs such as `$defs`, `$ref`, `keys`, `groups`, or
combinators.

## Usage

``` r
schema_infer(
  x,
  version = NULL,
  keys = c("none", "named", "required", "exact"),
  arrays = c("none", "rest")
)
```

## Arguments

- x:

  Example data to infer from.

- version:

  Optional schema document version string.

- keys:

  Strategy for inferring optional `keys` rules from observed names. Use
  `"none"` to skip names-rule inference, `"named"` to require named
  inputs, `"required"` to require the observed names to be present, or
  `"exact"` to require the observed names in the observed order.

- arrays:

  Strategy for inferring unnamed lists. Use `"none"` to keep unnamed
  lists generic, or `"rest"` to infer them as unnamed containers whose
  observed element schemas are stored in `rest`.

## Value

A `SchemaDoc` inferred from `x`.

## Details

To parse an existing schema DSL document, use
[`schema_doc()`](https://hongyuanjia.github.io/schemate/reference/schema_doc.md)
or
[`schema_read()`](https://hongyuanjia.github.io/schemate/reference/schema-json.md)
instead.

## Examples

``` r
payload <- list(items = list(list(id = 1L), list(id = 2L)))
schema <- schema_infer(payload, keys = "named", arrays = "rest")
as.list(schema)$fields$items$keys
#> $type
#> [1] "unnamed"
#> 
```
