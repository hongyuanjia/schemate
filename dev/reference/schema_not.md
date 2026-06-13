# Create a `not` schema combinator fragment

Create a `not` schema combinator fragment

## Usage

``` r
schema_not(branch, description = NULL)
```

## Arguments

- branch:

  Branch schema fragment.

- description:

  Optional node description.

## Value

A raw schema fragment accepted by
[`schema_doc()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_doc.md)
and schema edit verbs.

## Examples

``` r
schema <- schema_doc(schema_not(schema_check("null")))
schema
#> {
#>   "not": {
#>     "check": {
#>       "kind": "null"
#>     }
#>   }
#> }

schema_validate(schema, "ok", mode = "test")
#> [1] TRUE
```
