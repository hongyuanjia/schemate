# Delete a field schema from a container node

Delete a field schema from a container node

## Usage

``` r
schema_del_field(x, name, path = "$", missing = "error")
```

## Arguments

- x:

  A `SchemaDoc`.

- name:

  Field name to remove.

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
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   }
#> }
schema <- schema_add_field(schema, "id", schema_check("int"))
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "fields": {
#>     "id": {
#>       "check": {
#>         "kind": "int"
#>       }
#>     }
#>   }
#> }
schema <- schema_del_field(schema, "id")
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   }
#> }
```
