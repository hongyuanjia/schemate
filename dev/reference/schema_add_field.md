# Add a field schema to a container node

Add a field schema to a container node

## Usage

``` r
schema_add_field(x, name, field, path = "$", overwrite = FALSE)
```

## Arguments

- x:

  A `SchemaDoc`.

- name:

  Field name to add.

- field:

  Schema fragment using the same list syntax accepted by
  [`schema_doc()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_doc.md),
  or a fragment produced by helpers such as
  [`schema_check()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_check.md).

- path:

  Path to the target container node. Use `$` for the root node. Bare
  field segments such as `$id` implicitly traverse container `fields`.
  Use `$fields$id` to write the explicit field path. Backtick-quote
  field names that contain path operators, for example `` $`a$b`  ``.

- overwrite:

  Logical flag indicating whether an existing field of the same name
  should be replaced.

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
schema <- schema_add_field(schema, "id", schema_check("int", lower = 1))
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
