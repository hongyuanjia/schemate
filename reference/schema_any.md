# Create an `any` schema combinator fragment

Create an `any` schema combinator fragment

## Usage

``` r
schema_any(..., description = NULL)
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
schema <- schema_doc(schema_any(schema_check("int"), schema_check("string")))
schema
#> {
#>   "any": [
#>     {
#>       "check": {
#>         "kind": "int"
#>       }
#>     },
#>     {
#>       "check": {
#>         "kind": "string"
#>       }
#>     }
#>   ]
#> }

schema_validate(schema, "ok", mode = "test")
#> [1] TRUE
```
