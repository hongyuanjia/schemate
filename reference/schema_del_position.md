# Delete a position schema from an unnamed container node

Delete a position schema from an unnamed container node

## Usage

``` r
schema_del_position(x, index, path = "$", missing = "error")
```

## Arguments

- x:

  A `SchemaDoc`.

- index:

  1-based position index to remove.

- path:

  Path to the target unnamed container node. Use `$` for the root node.

- missing:

  Missing-target behavior. Use `"error"` to raise an error or `"ignore"`
  to leave the schema unchanged.

## Value

A modified `SchemaDoc`.

## Examples

``` r
schema <- schema_doc(list(check = list(kind = "list"), keys = list(type = "unnamed")))
schema <- schema_add_position(schema, 1, schema_check("string"))
schema <- schema_del_position(schema, 1)
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "keys": {
#>     "type": "unnamed"
#>   }
#> }

as.list(schema)$positions
#> NULL
```
