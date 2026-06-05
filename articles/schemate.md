# Introduction to schemate

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

schema
#> {
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
#>             "kind": "string"
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
#>               "kind": "int"
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
#>                 "kind": "string"
#>               }
#>             }
#>           }
#>         }
#>       }
#>     }
#>   }
#> }
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

## Batch Edits

When the same edit should apply to several schema nodes, find the
logical paths first, then replace the matching nodes. Logical paths
expand grouped fields into ordinary field paths.

``` r

schema_find(schema, schema_where_path("(^|\\$)id$"))
#> [1] "$request$id"    "$items$rest$id"

schema <- schema_replace_where(
    schema,
    schema_where_path("(^|\\$)id$"),
    schema_check("int", lower = 1)
)
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
#>             "kind": "int",
#>             "lower": 1
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
#>             "kind": "int",
#>             "lower": 1
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

Below is an example schema file shipped with this package.
[`system.file()`](https://rdrr.io/r/base/system.file.html).

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
#> [1] FALSE

bad <- payload
bad$items[[1L]]$id <- 0L
restored |>
    schema_validate(bad, mode = "check", name = "payload")
#> [1] "payload$request$id: Must be of type 'single integerish value', not 'character'"
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
score_schema
#> {
#>   "check": {
#>     "kind": "data_frame"
#>   },
#>   "keys": {
#>     "type": "named",
#>     "must.include": ["id", "name", "score"]
#>   },
#>   "fields": {
#>     "id": {
#>       "check": {
#>         "kind": "integerish",
#>         "any.missing": false
#>       }
#>     },
#>     "name": {
#>       "check": {
#>         "kind": "character"
#>       }
#>     },
#>     "score": {
#>       "check": {
#>         "kind": "numeric",
#>         "lower": 0,
#>         "upper": 10
#>       }
#>     }
#>   }
#> }

score_schema |>
    schema_validate(scores, mode = "test")
#> [1] TRUE

bad_scores <- transform(scores, score = as.character(score))
score_schema |>
    schema_validate(bad_scores, mode = "check", name = "scores")
#> [1] "scores$score: Must be of type 'numeric', not 'character'"
```

## Validation Modes

Use validation modes according to the caller. The examples below use one
small schema so the return shape is easy to compare.

``` r

mode_schema <- schema_doc(list(
    check = list(kind = "list"),
    fields = list(id = schema_check("int", lower = 1))
))
mode_good <- list(id = 1L)
mode_bad <- list(id = 0L)
mode_schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "fields": {
#>     "id": {
#>       "check": {
#>         "kind": "int",
#>         "lower": 1
#>       }
#>     }
#>   }
#> }
```

`assert` is the default for application code. It returns the input
invisibly on success and throws an error on failure.

``` r

mode_schema |>
    schema_validate(mode_good)
try(mode_schema |>
    schema_validate(mode_bad, name = "payload"))
#> Error : payload$id: Element 1 is not >= 1
```

`check` returns `TRUE` or a diagnostic string. It is useful when you
want to show or store the validation message.

``` r

mode_schema |>
    schema_validate(mode_bad, mode = "check", name = "payload")
#> [1] "payload$id: Element 1 is not >= 1"
```

`test` returns a plain boolean. It is useful for control flow.

``` r

mode_schema |>
    schema_validate(mode_good, mode = "test")
#> [1] TRUE
mode_schema |>
    schema_validate(mode_bad, mode = "test")
#> [1] FALSE
```

`expect` returns a testthat-style expectation object for package tests.

``` r

mode_schema |>
    schema_validate(mode_good, mode = "expect")
#> <expectation_success/expectation/condition>
#> As expected
```
