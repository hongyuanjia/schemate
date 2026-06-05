# Create schema query predicates

Create schema query predicates

## Usage

``` r
schema_where_path(pattern, fixed = FALSE)

schema_where_check(kind = NULL)
```

## Arguments

- pattern:

  Pattern passed to [`grepl()`](https://rdrr.io/r/base/grep.html) for
  matching schema paths.

- fixed:

  Whether `pattern` should be matched literally.

- kind:

  Optional check kind to match, such as `"list"` or `"int"`.

## Value

A predicate function with signature `function(path, node)`.

## Examples

``` r
by_path <- schema_where_path("(^|\\$)`date-parts`\\$rest$")
by_int <- schema_where_check("int")

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

schema_find(schema, by_int)
#> [1] "$id"
```
