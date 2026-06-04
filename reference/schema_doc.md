# Parse schema documents

`schema_doc()` parses a schema DSL list into a schemate schema document
object.

## Usage

``` r
schema_doc(x, path = NULL)
```

## Arguments

- x:

  A schema DSL list or an existing schemate schema document.

- path:

  Optional source path stored as runtime metadata.

## Value

A schemate schema document object.

## Details

Normal users usually create schema documents with
[`schema_infer()`](https://hongyuanjia.github.io/schemate/reference/schema_infer.md),
[`schema_read()`](https://hongyuanjia.github.io/schemate/reference/schema-json.md),
or the edit helpers. Use `schema_doc()` when you are hand-authoring a
schema as an R list.

## Examples

``` r
doc <- schema_doc(list(check = list(kind = "string", min.chars = 1)))
doc
#> {
#>   "check": {
#>     "kind": "string",
#>     "min.chars": 1
#>   }
#> }

schema_validate(doc, "ok")
```
