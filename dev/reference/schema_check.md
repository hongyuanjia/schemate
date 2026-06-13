# Create a schema check fragment

`schema_check()` creates a raw schema fragment with a `check` operator.
The helper performs only lightweight structural validation; semantic
validation of `kind` and check arguments is handled by
[`schema_doc()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_doc.md)
and schema edit verbs.

## Usage

``` r
schema_check(kind, ..., description = NULL)
```

## Arguments

- kind:

  Check kind string.

- ...:

  Additional named checkmate arguments stored inside `check`.

- description:

  Optional node description.

## Value

A raw schema fragment accepted by
[`schema_doc()`](https://hongyuanjia.github.io/schemate/dev/reference/schema_doc.md)
and schema edit verbs.

## Examples

``` r
schema_check("string", min.chars = 1)
#> $check
#> $check$kind
#> [1] "string"
#> 
#> $check$min.chars
#> [1] 1
#> 
#> 
schema <- schema_doc(schema_check("string", min.chars = 1))
schema
#> {
#>   "check": {
#>     "kind": "string",
#>     "min.chars": 1
#>   }
#> }
```
