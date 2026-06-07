# Flatten a schema for repeated validation

`schema_flatten()` converts a schema document, raw schema DSL list, or
flat runtime schema node into a `SchemaFlat`. Reuse the flattened schema
when validating many inputs against the same schema.

## Usage

``` r
schema_flatten(x)
```

## Arguments

- x:

  A schema document, raw schema DSL list, `SchemaFlat`, or flattened
  flat schema node.

## Value

A flattened `SchemaFlat`.

## Examples

``` r
schema <- schema_doc(list(
    check = list(kind = "list"),
    fields = list(id = list(check = list(kind = "int", lower = 1)))
))

flat <- schema_flatten(schema)
schema_validate(flat, list(id = 1L), mode = "test")
#> [1] TRUE
```
