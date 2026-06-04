# Create a schema group fragment

Create a schema group fragment

## Usage

``` r
schema_group(names, value, description = NULL)
```

## Arguments

- names:

  Field names covered by the group.

- value:

  Schema node fragment containing exactly one primary operator.

- description:

  Optional group description.

## Value

A raw schema group fragment accepted in a schema document `groups` list
or by
[`schema_add_group()`](https://hongyuanjia.github.io/schemate/reference/schema_add_group.md).

## Examples

``` r
schema <- schema_doc(list(
    check = list(kind = "list"),
    groups = list(schema_group(c("x", "y"), schema_check("number")))
))
schema_validate(schema, list(x = 1, y = 2), mode = "test")
#> [1] TRUE
```
