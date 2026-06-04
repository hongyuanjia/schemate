# Read and write schema JSON

`schema_read()` reads schema JSON into a `SchemaDoc`. `schema_write()`
serializes schema objects to schema JSON. Both functions require the
suggested package `jsonlite`.

## Usage

``` r
schema_write(x, path, overwrite = FALSE, pretty = TRUE, auto_unbox = TRUE)

schema_read(txt)
```

## Arguments

- x:

  A schema object accepted by
  [`as.list()`](https://rdrr.io/r/base/list.html), usually a
  `SchemaDoc`.

- path:

  Output file path.

- overwrite:

  Whether an existing output file may be overwritten.

- pretty:

  Whether JSON output should be pretty-printed.

- auto_unbox:

  Passed to
  [`jsonlite::write_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html).

- txt:

  JSON text, local file path, or URL accepted by
  [`jsonlite::fromJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html).

## Value

`schema_read()` returns a `SchemaDoc`. `schema_write()` invisibly
returns `path`.

## Examples

``` r
schema <- schema_infer(list(id = 1L))
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "fields": {
#>     "id": {
#>       "check": {
#>         "kind": "int"
#>       }
#>     }
#>   }
#> }

path <- tempfile(fileext = ".json")
schema_write(schema, path)
restored <- schema_read(path)
restored
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "fields": {
#>     "id": {
#>       "check": {
#>         "kind": "int"
#>       }
#>     }
#>   }
#> }
```
