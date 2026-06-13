# Replace a schema node

Replace a schema node

## Usage

``` r
schema_replace(x, path = "$", value)
```

## Arguments

- x:

  A `SchemaDoc`.

- path:

  Path to the target schema node. Use `$` for the root node. Bare field
  segments such as `$id` implicitly traverse container `fields`. Use
  `$fields$id` to write the explicit field path. Backtick-quote field
  names that contain path operators, for example `` $`a$b`  ``.

- value:

  Replacement schema fragment using the same list syntax accepted by
  [`schema_doc()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_doc.md),
  or a fragment produced by helpers such as
  [`schema_check()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_check.md)
  or
  [`schema_ref()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_ref.md).

## Value

A modified `SchemaDoc`.

## Examples

``` r
schema <- schema_doc(list(
    check = list(kind = "list"),
    fields = list(id = schema_check("int"))
))
schema <- schema_replace(schema, "$id", schema_check("int", lower = 1))
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
```
