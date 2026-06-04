# Set or replace a container rest schema

Set or replace a container rest schema

## Usage

``` r
schema_set_rest(x, field, path = "$")
```

## Arguments

- x:

  A `SchemaDoc`.

- field:

  Schema fragment using the same list syntax accepted by
  [`schema_doc()`](https://hongyuanjia.github.io/schemate/reference/schema_doc.md),
  or a fragment produced by helpers such as
  [`schema_check()`](https://hongyuanjia.github.io/schemate/reference/schema_check.md),
  to store as the `rest` schema.

- path:

  Path to the target container node. Use `$` for the root node. Bare
  field segments such as `$id` implicitly traverse container `fields`.
  Use `$fields$id` to write the explicit field path. Backtick-quote
  field names that contain path operators, for example `` $`a$b`  ``.

## Value

A modified `SchemaDoc`.

## Examples

``` r
schema <- schema_doc(list(
    check = list(kind = "list"),
    keys = list(type = "unnamed")
))
schema <- schema_set_rest(schema, schema_check("string"))
schema_validate(schema, list("a", "b"), mode = "test")
#> [1] TRUE
```
