# Delete a schema definition

Delete a schema definition

## Usage

``` r
schema_del_def(x, name, error_if_missing = TRUE)
```

## Arguments

- x:

  A `SchemaDoc`.

- name:

  Definition name to remove.

- error_if_missing:

  Logical flag indicating whether a missing definition should raise an
  error.

## Value

A modified `SchemaDoc`.

## Examples

``` r
schema <- schema_doc(schema_check("string"))
schema <- schema_add_def(schema, "text", schema_check("string"))
schema <- schema_del_def(schema, "text")
schema
#> {
#>   "check": {
#>     "kind": "string"
#>   }
#> }

as.list(schema)$`$defs`
#> NULL
```
