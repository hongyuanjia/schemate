# Set a schema node keys rule

Set a schema node keys rule

## Usage

``` r
schema_set_keys(x, path = "$", ...)
```

## Arguments

- x:

  A `SchemaDoc`.

- path:

  Path to the target schema node. Use `$` for the root node. Bare field
  segments such as `$id` implicitly traverse container `fields`. Use
  `$fields$id` to write the explicit field path. Backtick-quote field
  names that contain path operators, for example `` $`a$b`  ``.

- ...:

  Named `keys` rule arguments passed through to the schema DSL.

## Value

A modified `SchemaDoc`.
