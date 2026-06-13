# Modify schema nodes selected by a predicate

`schema_modify_where()` modifies every schema node matched by `where`.
`schema_replace_where()` is a convenience wrapper that replaces all
matched nodes with the same schema fragment.

## Usage

``` r
schema_modify_where(x, where, fn, defs = TRUE, missing = "ignore")

schema_replace_where(x, where, value, defs = TRUE, missing = "ignore")
```

## Arguments

- x:

  A schema document or raw schema DSL list.

- where:

  Predicate function with signature `function(path, node)`.

- fn:

  Function with signature `function(path, node)` returning a schema
  fragment or `SchemaNode`.

- defs:

  Whether to include root `$defs` entries.

- missing:

  Missing-match behavior. Use `"error"` to raise an error when `where`
  matches no paths or `"ignore"` to leave the schema unchanged.

- value:

  Replacement schema fragment or `SchemaNode`.

## Value

A modified `SchemaDoc`.

## Details

Batch edits operate on logical paths. Editing every path inside a
grouped schema field preserves the group when the replacement targets
are structurally equivalent; partial edits or differing replacement
targets split the group into per-field bindings. If `where` matches both
a node and one of its descendants in the same call, the edit errors and
asks you to narrow the selector.

## Examples

``` r
schema <- schema_compact(schema_infer(list(
    issued = list(`date-parts` = list(list(2024L))),
    created = list(`date-parts` = list(list(2024L)))
), arrays = "rest"))
schema <- schema_add_def(schema, "year", schema_check("int", lower = 0))
schema
#> {
#>   "$defs": {
#>     "year": {
#>       "check": {
#>         "kind": "int",
#>         "lower": 0
#>       }
#>     }
#>   },
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

schema <- schema_replace_where(
    schema,
    schema_where_path("(^|\\$)`date-parts`\\$rest$"),
    schema_ref("year")
)
schema
#> {
#>   "$defs": {
#>     "year": {
#>       "check": {
#>         "kind": "int",
#>         "lower": 0
#>       }
#>     }
#>   },
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
#>             "$ref": "#/$defs/year"
#>           }
#>         }
#>       }
#>     }
#>   ]
#> }
```
