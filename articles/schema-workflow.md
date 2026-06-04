# Get Started: Schema Lifecycle

`schemate` is built around one lifecycle:

1.  infer a conservative schema from an example object;
2.  compact repeated observed structure;
3.  edit the schema until it expresses the real input contract;
4.  write the schema to JSON;
5.  read the schema back where it is needed;
6.  validate new input.

## Nested List Contract

The most useful `schemate` workflows start with a nested R object such
as a package configuration, a model payload, or a JSON-like API
response.

``` r

library(schemate)

payload <- list(
  request = list(id = "run-001", retry = FALSE),
  items = list(
    list(id = 1L, label = "alpha", tags = list("r", "schema")),
    list(id = 2L, label = "beta", tags = list("validation"))
  )
)

schema <- payload |>
  schema_infer(keys = "named", arrays = "rest") |>
  schema_compact()

as.list(schema)$fields$items
#> $check
#> $check$kind
#> [1] "list"
#> 
#> 
#> $keys
#> $keys$type
#> [1] "unnamed"
#> 
#> 
#> $rest
#> $rest$check
#> $rest$check$kind
#> [1] "list"
#> 
#> 
#> $rest$keys
#> $rest$keys$type
#> [1] "named"
#> 
#> 
#> $rest$fields
#> $rest$fields$id
#> $rest$fields$id$check
#> $rest$fields$id$check$kind
#> [1] "int"
#> 
#> 
#> 
#> $rest$fields$label
#> $rest$fields$label$check
#> $rest$fields$label$check$kind
#> [1] "string"
#> 
#> 
#> 
#> $rest$fields$tags
#> $rest$fields$tags$check
#> $rest$fields$tags$check$kind
#> [1] "list"
#> 
#> 
#> $rest$fields$tags$keys
#> $rest$fields$tags$keys$type
#> [1] "unnamed"
#> 
#> 
#> $rest$fields$tags$rest
#> $rest$fields$tags$rest$check
#> $rest$fields$tags$rest$check$kind
#> [1] "string"
```

`arrays = "rest"` treats unnamed lists as homogeneous arrays. The
observed item schemas are stored in `rest`, and
[`schema_compact()`](https://hongyuanjia.github.io/schemate/reference/schema_compact.md)
merges compatible observed alternatives into one maintainable item
schema.

## Refine

Inference captures observed structure. It does not guess business rules,
so the next step is to refine the parts of the contract that matter.

``` r

schema <- schema |>
  schema_set_desc("$", "Example request payload.") |>
  schema_replace("$request$id", schema_check("string", min.chars = 1)) |>
  schema_replace("$items$rest$id", schema_check("int", lower = 1)) |>
  schema_set_rest(schema_check("string", min.chars = 1), path = "$items$rest$tags")

schema
#> {
#>   "description": "Example request payload.",
#>   "check": {
#>     "kind": "list"
#>   },
#>   "keys": {
#>     "type": "named"
#>   },
#>   "fields": {
#>     "request": {
#>       "check": {
#>         "kind": "list"
#>       },
#>       "keys": {
#>         "type": "named"
#>       },
#>       "fields": {
#>         "id": {
#>           "check": {
#>             "kind": "string",
#>             "min.chars": 1
#>           }
#>         },
#>         "retry": {
#>           "check": {
#>             "kind": "flag"
#>           }
#>         }
#>       }
#>     },
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
#>               "kind": "int",
#>               "lower": 1
#>             }
#>           },
#>           "label": {
#>             "check": {
#>               "kind": "string"
#>             }
#>           },
#>           "tags": {
#>             "check": {
#>               "kind": "list"
#>             },
#>             "keys": {
#>               "type": "unnamed"
#>             },
#>             "rest": {
#>               "check": {
#>                 "kind": "string",
#>                 "min.chars": 1
#>               }
#>             }
#>           }
#>         }
#>       }
#>     }
#>   }
#> }
```

Paths use `$` for the root node. Bare field paths such as `$request$id`
traverse container fields. Inferred unnamed array schemas are reached
through `rest`, as in `$items$rest$id`.

## Write And Read

[`schema_read()`](https://hongyuanjia.github.io/schemate/reference/schema-json.md)
and
[`schema_write()`](https://hongyuanjia.github.io/schemate/reference/schema-json.md)
require the suggested package `jsonlite`.

``` r

path <- tempfile(fileext = ".json")
schema_write(schema, path)

restored <- schema_read(path)
restored
#> {
#>   "description": "Example request payload.",
#>   "check": {
#>     "kind": "list"
#>   },
#>   "keys": {
#>     "type": "named"
#>   },
#>   "fields": {
#>     "request": {
#>       "check": {
#>         "kind": "list"
#>       },
#>       "keys": {
#>         "type": "named"
#>       },
#>       "fields": {
#>         "id": {
#>           "check": {
#>             "kind": "string",
#>             "min.chars": 1
#>           }
#>         },
#>         "retry": {
#>           "check": {
#>             "kind": "flag"
#>           }
#>         }
#>       }
#>     },
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
#>               "kind": "int",
#>               "lower": 1
#>             }
#>           },
#>           "label": {
#>             "check": {
#>               "kind": "string"
#>             }
#>           },
#>           "tags": {
#>             "check": {
#>               "kind": "list"
#>             },
#>             "keys": {
#>               "type": "unnamed"
#>             },
#>             "rest": {
#>               "check": {
#>                 "kind": "string",
#>                 "min.chars": 1
#>               }
#>             }
#>           }
#>         }
#>       }
#>     }
#>   }
#> }
```

Package authors can store schema files in `inst/extdata` and load them
with [`system.file()`](https://rdrr.io/r/base/system.file.html).

``` r

person_schema <- system.file("extdata", "person-schema.json", package = "schemate")
schema_read(person_schema)
#> {
#>   "version": "1.0.0",
#>   "description": "Person-like named list schema.",
#>   "check": {
#>     "kind": "list"
#>   },
#>   "keys": {
#>     "type": "named",
#>     "must.include": ["id", "name"]
#>   },
#>   "fields": {
#>     "id": {
#>       "description": "Stable integer identifier.",
#>       "check": {
#>         "kind": "integerish",
#>         "len": 1
#>       }
#>     },
#>     "name": {
#>       "description": "Display name.",
#>       "check": {
#>         "kind": "string",
#>         "min.chars": 1
#>       }
#>     },
#>     "email": {
#>       "description": "Optional email address.",
#>       "check": {
#>         "kind": "string",
#>         "min.chars": 3,
#>         "null.ok": true
#>       }
#>     }
#>   }
#> }
```

## Validate

``` r

good <- payload
restored |>
  schema_validate(good, mode = "test")
#> [1] TRUE

bad <- payload
bad$items[[1L]]$id <- 0L
restored |>
  schema_validate(bad, mode = "check", name = "payload")
#> [1] "payload$items[[1]]$id: Element 1 is not >= 1"
```

Diagnostics include a path prefix. A message starting with
`payload$items[[1]]$id` means the root object named `payload` failed
inside the first item at field `id`. Messages from leaf checks come from
checkmate, while container messages are produced by `schemate` when
fields, names, branches, or references do not match.

## Data Frame Inputs

Data frames are also container objects. `schemate` is not a data quality
reporting framework; use it when you want an input schema that can be
inferred, edited, saved, and reused.

``` r

scores <- data.frame(
  id = 1:3,
  name = c("alice", "bob", "carol"),
  score = c(9.5, 8.0, 7.5)
)

score_schema <- scores |>
  schema_infer(keys = "required") |>
  schema_replace("$id", schema_check("integerish", any.missing = FALSE)) |>
  schema_replace("$score", schema_check("numeric", lower = 0, upper = 10))

score_schema |>
  schema_validate(scores, mode = "test")
#> [1] TRUE

bad_scores <- transform(scores, score = as.character(score))
score_schema |>
  schema_validate(bad_scores, mode = "check", name = "scores")
#> [1] "scores$score: Must be of type 'numeric', not 'character'"
```

## Validation Modes

Use validation modes according to the caller:

| Mode     | Use when                                                 |
|----------|----------------------------------------------------------|
| `assert` | invalid input should stop execution                      |
| `check`  | you want a diagnostic string                             |
| `test`   | control flow needs a boolean                             |
| `expect` | tests should receive a testthat-style expectation object |
