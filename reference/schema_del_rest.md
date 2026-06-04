# Delete a container rest schema

Delete a container rest schema

## Usage

``` r
schema_del_rest(x, path = "$", error_if_missing = TRUE)
```

## Arguments

- x:

  A `SchemaDoc`.

- path:

  Path to the target container node. Use `$` for the root node. Bare
  field segments such as `$id` implicitly traverse container `fields`.
  Use `$fields$id` to write the explicit field path. Backtick-quote
  field names that contain path operators, for example `` $`a$b`  ``.

- error_if_missing:

  Logical flag indicating whether a missing `rest` schema should raise
  an error.

## Value

A modified `SchemaDoc`.
