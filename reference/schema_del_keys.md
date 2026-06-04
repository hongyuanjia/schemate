# Delete a schema node keys rule

Delete a schema node keys rule

## Usage

``` r
schema_del_keys(x, path = "$", error_if_missing = TRUE)
```

## Arguments

- x:

  A `SchemaDoc`.

- path:

  Path to the target schema node. Use `$` for the root node. Bare field
  segments such as `$id` implicitly traverse container `fields`. Use
  `$fields$id` to write the explicit field path. Backtick-quote field
  names that contain path operators, for example `` $`a$b`  ``.

- error_if_missing:

  Logical flag indicating whether a missing `keys` rule should raise an
  error.

## Value

A modified `SchemaDoc`.

## Examples

``` r
schema <- schema_doc(list(check = list(kind = "list"), keys = list(type = "named")))
schema <- schema_del_keys(schema)
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   }
#> }

as.list(schema)$keys
#> NULL
```
