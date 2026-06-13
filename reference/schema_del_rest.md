# Delete a container rest schema

Delete a container rest schema

## Usage

``` r
schema_del_rest(x, path = "$", missing = "error")
```

## Arguments

- x:

  A `SchemaDoc`.

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
schema <- schema_doc(list(check = list(kind = "list")))
schema <- schema_set_rest(schema, schema_check("string"))
schema <- schema_del_rest(schema)
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   }
#> }

as.list(schema)$rest
#> NULL
```
