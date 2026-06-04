# Compact a schema document

`schema_compact()` simplifies schema documents produced by inference or
hand-authoring. It can merge observed array element alternatives and
group sibling fields that share identical schemas.

## Usage

``` r
schema_compact(x, arrays = TRUE, groups = TRUE)
```

## Arguments

- x:

  A `SchemaDoc` or raw schema DSL list.

- arrays:

  Whether to merge compatible `any` branches, especially the observed
  element alternatives produced by `schema_infer(arrays = "rest")`.

- groups:

  Whether to combine sibling fields with identical schemas into
  `groups`.

## Value

A compacted `SchemaDoc`.

## Examples

``` r
schema <- schema_infer(
    list(items = list(list(id = 1L, name = "a"), list(id = 2L, label = "b"))),
    keys = "named",
    arrays = "rest"
)
schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "keys": {
#>     "type": "named"
#>   },
#>   "fields": {
#>     "items": {
#>       "check": {
#>         "kind": "list"
#>       },
#>       "keys": {
#>         "type": "unnamed"
#>       },
#>       "rest": {
#>         "any": [
#>           {
#>             "check": {
#>               "kind": "list"
#>             },
#>             "keys": {
#>               "type": "named"
#>             },
#>             "fields": {
#>               "id": {
#>                 "check": {
#>                   "kind": "int"
#>                 }
#>               },
#>               "name": {
#>                 "check": {
#>                   "kind": "string"
#>                 }
#>               }
#>             }
#>           },
#>           {
#>             "check": {
#>               "kind": "list"
#>             },
#>             "keys": {
#>               "type": "named"
#>             },
#>             "fields": {
#>               "id": {
#>                 "check": {
#>                   "kind": "int"
#>                 }
#>               },
#>               "label": {
#>                 "check": {
#>                   "kind": "string"
#>                 }
#>               }
#>             }
#>           }
#>         ]
#>       }
#>     }
#>   }
#> }

compact <- schema_compact(schema)
compact
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "keys": {
#>     "type": "named"
#>   },
#>   "fields": {
#>     "items": {
#>       "check": {
#>         "kind": "list"
#>       },
#>       "keys": {
#>         "type": "unnamed"
#>       },
#>       "rest": {
#>         "check": {
#>           "kind": "list"
#>         },
#>         "keys": {
#>           "type": "named"
#>         },
#>         "fields": {
#>           "id": {
#>             "check": {
#>               "kind": "int"
#>             }
#>           }
#>         },
#>         "groups": [
#>           {
#>             "names": ["name", "label"],
#>             "check": {
#>               "kind": "string"
#>             }
#>           }
#>         ]
#>       }
#>     }
#>   }
#> }

names(as.list(compact)$fields$items$rest$fields)
#> [1] "id"
```
