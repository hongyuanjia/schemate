# Set or remove a schema node description

Set or remove a schema node description

## Usage

``` r
schema_set_desc(x, path = "$", description = NULL)
```

## Arguments

- x:

  A `SchemaDoc`.

- path:

  Path to the target schema node. Use `$` for the root node. Bare field
  segments such as `$id` implicitly traverse container `fields`. Use
  `$fields$id` to write the explicit field path. Backtick-quote field
  names that contain path operators, for example `` $`a$b`  ``.

- description:

  Optional description string. Use `NULL` to remove the description.

## Value

A modified `SchemaDoc`.

## Examples

``` r
schema <- schema_doc(schema_check("string"))
schema <- schema_set_desc(schema, "$", "A non-empty label.")
schema
#> {
#>   "description": "A non-empty label.",
#>   "check": {
#>     "kind": "string"
#>   }
#> }

as.list(schema)$description
#> [1] "A non-empty label."
```
