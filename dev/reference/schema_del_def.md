# Delete a schema definition

Delete a schema definition

## Usage

``` r
schema_del_def(x, name, missing = "error")
```

## Arguments

- x:

  A `SchemaDoc`.

- name:

  Definition name to remove.

- missing:

  Missing-target behavior. Use `"error"` to raise an error or `"ignore"`
  to leave the schema unchanged.

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
