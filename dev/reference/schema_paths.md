# Query schema paths and matching nodes

`schema_paths()` lists editable logical schema paths. `schema_find()`
returns paths whose schema node satisfies a predicate.

## Usage

``` r
schema_paths(x, defs = TRUE)

schema_find(x, where, defs = TRUE)
```

## Arguments

- x:

  A schema document or raw schema DSL list.

- defs:

  Whether to include root `$defs` entries.

- where:

  Predicate function with signature `function(path, node)`.

## Value

A character vector of schema paths.

## Details

Logical paths describe fields as users see them in the validated data.
Grouped fields are expanded to one path per field.

## Examples

``` r
schema <- schema_compact(schema_infer(list(
    issued = list(`date-parts` = list(list(2024L))),
    created = list(`date-parts` = list(list(2024L)))
), arrays = "rest"))
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "groups": [
#>     {
#>       "names": ["issued", "created"],
#>       "check": {
#>         "kind": "list"
#>       },
#>       "fields": {
#>         "date-parts": {
#>           "check": {
#>             "kind": "list"
#>           },
#>           "keys": {
#>             "type": "unnamed"
#>           },
#>           "rest": {
#>             "check": {
#>               "kind": "list"
#>             },
#>             "keys": {
#>               "type": "unnamed"
#>             },
#>             "rest": {
#>               "check": {
#>                 "kind": "int"
#>               }
#>             }
#>           }
#>         }
#>       }
#>     }
#>   ]
#> }

schema_find(schema, schema_where_path("(^|\\$)`date-parts`\\$rest$"))
#> [1] "$issued$`date-parts`$rest"  "$created$`date-parts`$rest"
schema_find(schema, schema_where_check("int"))
#> [1] "$issued$`date-parts`$rest$rest"  "$created$`date-parts`$rest$rest"
```
