# Delete a position schema from an unnamed container node

Delete a position schema from an unnamed container node

## Usage

``` r
schema_del_position(x, index, path = "$", error_if_missing = TRUE)
```

## Arguments

- x:

  A `SchemaDoc`.

- index:

  1-based position index to remove.

- path:

  Path to the target unnamed container node. Use `$` for the root node.

- error_if_missing:

  Logical flag indicating whether a missing position schema should raise
  an error.

## Value

A modified `SchemaDoc`.
