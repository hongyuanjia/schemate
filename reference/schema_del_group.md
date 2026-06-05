# Delete a schema group from a container node

Delete a schema group from a container node

## Usage

``` r
schema_del_group(x, index, path = "$", missing = "error")
```

## Arguments

- x:

  A `SchemaDoc`.

- index:

  1-based group index to remove.

- path:

  Path to the target container node. Use `$` for the root node. Bare
  field segments such as `$id` implicitly traverse container `fields`.
  Use `$fields$id` to write the explicit field path. Backtick-quote
  field names that contain path operators, for example `` $`a$b`  ``.

- missing:

  Missing-target behavior. Use `"error"` to raise an error or `"ignore"`
  to leave the schema unchanged.

## Value

A modified `SchemaDoc`.

## Examples

``` r
schema <- schema_doc(list(
    check = list(kind = "list"),
    groups = list(schema_group(c("x", "y"), schema_check("number")))
))
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "groups": [
#>     {
#>       "names": ["x", "y"],
#>       "check": {
#>         "kind": "number"
#>       }
#>     }
#>   ]
#> }

schema_del_group(schema, 1)
#> {
#>   "check": {
#>     "kind": "list"
#>   }
#> }
```
