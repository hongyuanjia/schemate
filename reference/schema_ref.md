# Create a schema reference fragment

`schema_ref()` creates a local `$defs` reference fragment. `name` may be
either a bare definition name such as `"text"` or a local ref string of
the form `"#/$defs/text"`.

## Usage

``` r
schema_ref(name, description = NULL)
```

## Arguments

- name:

  Definition name or local `$defs` ref string.

- description:

  Optional node description.

## Value

A raw schema fragment accepted by
[`schema_doc()`](https://hongyuanjia.github.io/schemate/reference/schema_doc.md)
and schema edit verbs.

## Examples

``` r
schema <- schema_doc(list(
    `$defs` = list(text = schema_check("string")),
    `$ref` = "#/$defs/text"
))
schema
#> {
#>   "$defs": {
#>     "text": {
#>       "check": {
#>         "kind": "string"
#>       }
#>     }
#>   },
#>   "$ref": "#/$defs/text"
#> }

schema_validate(schema, "ok", mode = "test")
#> [1] TRUE
schema_ref("text")
#> $`$ref`
#> [1] "#/$defs/text"
#> 
```
