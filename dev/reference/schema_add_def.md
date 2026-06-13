# Add a schema definition

Add a schema definition

## Usage

``` r
schema_add_def(x, name, value, overwrite = FALSE)
```

## Arguments

- x:

  A `SchemaDoc`.

- name:

  Definition name to add.

- value:

  Schema fragment using the same list syntax accepted by
  [`schema_doc()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_doc.md),
  or a fragment produced by helpers such as
  [`schema_check()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_check.md),
  to store in `$defs`.

- overwrite:

  Logical flag indicating whether an existing definition of the same
  name should be replaced.

## Value

A modified `SchemaDoc`.

## Examples

``` r
schema <- schema_doc(schema_check("string"))
schema <- schema_add_def(schema, "text", schema_check("string"))
schema
#> {
#>   "$defs": {
#>     "text": {
#>       "check": {
#>         "kind": "string"
#>       }
#>     }
#>   },
#>   "check": {
#>     "kind": "string"
#>   }
#> }

names(as.list(schema)$`$defs`)
#> [1] "text"
```
