# Add a position schema to an unnamed container node

Add a position schema to an unnamed container node

## Usage

``` r
schema_add_position(x, index, value, path = "$")
```

## Arguments

- x:

  A `SchemaDoc`.

- index:

  1-based insertion index. `1` inserts at the front and
  `length(positions) + 1` appends.

- value:

  Schema fragment using the same list syntax accepted by
  [`schema_doc()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_doc.md),
  or a fragment produced by helpers such as
  [`schema_check()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_check.md).

- path:

  Path to the target unnamed container node. Use `$` for the root node.

## Value

A modified `SchemaDoc`.

## Examples

``` r
schema <- schema_doc(list(
    check = list(kind = "list"),
    keys = list(type = "unnamed")
))
schema <- schema_add_position(schema, 1, schema_check("string"))
schema <- schema_add_position(schema, 2, schema_check("int"))
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "keys": {
#>     "type": "unnamed"
#>   },
#>   "positions": [
#>     {
#>       "check": {
#>         "kind": "string"
#>       }
#>     },
#>     {
#>       "check": {
#>         "kind": "int"
#>       }
#>     }
#>   ]
#> }

schema_validate(schema, list("a", 1L), mode = "test")
#> [1] TRUE
```
