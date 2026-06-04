# Add a schema group to a container node

Add a schema group to a container node

## Usage

``` r
schema_add_group(x, group, path = "$")
```

## Arguments

- x:

  A `SchemaDoc`.

- group:

  Schema group fragment using the same list syntax accepted by
  [`schema_doc()`](https://hongyuanjia.github.io/schemate/reference/schema_doc.md),
  or a fragment produced by
  [`schema_group()`](https://hongyuanjia.github.io/schemate/reference/schema_group.md).

- path:

  Path to the target container node. Use `$` for the root node. Bare
  field segments such as `$id` implicitly traverse container `fields`.
  Use `$fields$id` to write the explicit field path. Backtick-quote
  field names that contain path operators, for example `` $`a$b`  ``.

## Value

A modified `SchemaDoc`.
