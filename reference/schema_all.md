# Create an `all` schema combinator fragment

Create an `all` schema combinator fragment

## Usage

``` r
schema_all(..., description = NULL)
```

## Arguments

- ...:

  Branch schema fragments.

- description:

  Optional node description.

## Value

A raw schema fragment accepted by
[`schema_doc()`](https://hongyuanjia.github.io/schemate/reference/schema_doc.md)
and schema edit verbs.

## Examples

``` r
schema <- schema_doc(schema_all(
    schema_check("string"),
    schema_check("string", min.chars = 1)
))
schema
#> {
#>   "all": [
#>     {
#>       "check": {
#>         "kind": "string"
#>       }
#>     },
#>     {
#>       "check": {
#>         "kind": "string",
#>         "min.chars": 1
#>       }
#>     }
#>   ]
#> }

schema_validate(schema, "ok", mode = "test")
#> [1] TRUE
```
