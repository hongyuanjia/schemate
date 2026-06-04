# Delete a schema group from a container node

Delete a schema group from a container node

## Usage

``` r
schema_del_group(x, index, path = "$", error_if_missing = TRUE)
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

- error_if_missing:

  Logical flag indicating whether a missing group should raise an error.

## Value

A modified `SchemaDoc`.

## Examples

``` r
schema <- schema_doc(list(
    check = list(kind = "list"),
    groups = list(schema_group(c("x", "y"), schema_check("number")))
))
schema <- schema_del_group(schema, 1)
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   }
#> }

as.list(schema)$groups
#> NULL
```
