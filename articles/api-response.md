# API Response Examples

Real API responses often contain nested JSON arrays. A useful workflow
is:

1.  read the response into R with `jsonlite`;
2.  infer an observed schema with `arrays = "rest"`;
3.  compact repeated alternatives into a maintainable shape;
4.  refine the few places where the API contract is stricter than the
    example.

Use `simplifyVector = FALSE` when the goal is to validate the original
JSON-like structure. If jsonlite simplifies arrays into vectors or data
frames, that simplified R object is still valid to check, but it is no
longer a direct view of the raw JSON response.

## GitHub Search

For live data, read a GitHub REST API response without simplifying JSON
arrays into data frames:

``` r

github_payload <- jsonlite::fromJSON(
    "https://api.github.com/search/repositories?q=language:R+schema",
    simplifyVector = FALSE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
)
```

This vignette uses a curated subset of a real saved response so it can
run without network access. The source URL and capture details are
stored beside the JSON file in `inst/extdata/api/SOURCE.md`.

``` r

github_payload <- jsonlite::fromJSON(
    payload_path("github-search-repositories.json"),
    simplifyVector = FALSE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
)
jsonlite::toJSON(github_payload, pretty = TRUE, auto_unbox = TRUE)
#> {
#>   "total_count": 167,
#>   "incomplete_results": false,
#>   "items": [
#>     {
#>       "id": 48069228,
#>       "node_id": "MDEwOlJlcG9zaXRvcnk0ODA2OTIyOA==",
#>       "name": "sevenbridges-r",
#>       "full_name": "sbg/sevenbridges-r",
#>       "private": false,
#>       "html_url": "https://github.com/sbg/sevenbridges-r",
#>       "description": "Seven Bridges API Client, CWL Schema, Meta Schema, and SDK Helper in R",
#>       "fork": false,
#>       "created_at": "2015-12-15T21:10:57Z",
#>       "updated_at": "2026-04-13T07:53:29Z",
#>       "pushed_at": "2022-01-28T14:06:08Z",
#>       "size": 3572,
#>       "stargazers_count": 37,
#>       "watchers_count": 37,
#>       "language": "R",
#>       "has_issues": true,
#>       "has_projects": true,
#>       "has_downloads": true,
#>       "has_wiki": true,
#>       "has_pages": true,
#>       "has_discussions": false,
#>       "forks_count": 14,
#>       "archived": false,
#>       "disabled": false,
#>       "open_issues_count": 13,
#>       "allow_forking": true,
#>       "is_template": false,
#>       "topics": [
#>         "api-client",
#>         "bioconductor",
#>         "bioinformatics",
#>         "cloud",
#>         "common-workflow-language",
#>         "sevenbridges"
#>       ],
#>       "visibility": "public",
#>       "default_branch": "master",
#>       "score": 1,
#>       "owner": {
#>         "login": "sbg",
#>         "id": 233118,
#>         "node_id": "MDEyOk9yZ2FuaXphdGlvbjIzMzExOA==",
#>         "html_url": "https://github.com/sbg",
#>         "type": "Organization",
#>         "site_admin": false
#>       },
#>       "license": {
#>         "key": "apache-2.0",
#>         "name": "Apache License 2.0",
#>         "spdx_id": "Apache-2.0",
#>         "url": "https://api.github.com/licenses/apache-2.0",
#>         "node_id": "MDc6TGljZW5zZTI="
#>       }
#>     },
#>     {
#>       "id": 134324345,
#>       "node_id": "MDEwOlJlcG9zaXRvcnkxMzQzMjQzNDU=",
#>       "name": "dataspice",
#>       "full_name": "ropensci/dataspice",
#>       "private": false,
#>       "html_url": "https://github.com/ropensci/dataspice",
#>       "description": ":hot_pepper: Create lightweight schema.org descriptions of your datasets",
#>       "fork": false,
#>       "created_at": "2018-05-21T20:55:32Z",
#>       "updated_at": "2025-12-21T21:16:10Z",
#>       "pushed_at": "2025-09-24T14:25:06Z",
#>       "size": 3188,
#>       "stargazers_count": 164,
#>       "watchers_count": 164,
#>       "language": "R",
#>       "has_issues": true,
#>       "has_projects": true,
#>       "has_downloads": true,
#>       "has_wiki": true,
#>       "has_pages": false,
#>       "has_discussions": false,
#>       "forks_count": 26,
#>       "archived": false,
#>       "disabled": false,
#>       "open_issues_count": 34,
#>       "allow_forking": true,
#>       "is_template": false,
#>       "topics": [
#>         "data",
#>         "dataset",
#>         "metadata",
#>         "r",
#>         "r-package",
#>         "rstats",
#>         "schema-org",
#>         "unconf",
#>         "unconf18"
#>       ],
#>       "visibility": "public",
#>       "default_branch": "main",
#>       "score": 1,
#>       "owner": {
#>         "login": "ropensci",
#>         "id": 1200269,
#>         "node_id": "MDEyOk9yZ2FuaXphdGlvbjEyMDAyNjk=",
#>         "html_url": "https://github.com/ropensci",
#>         "type": "Organization",
#>         "site_admin": false
#>       },
#>       "license": {
#>         "key": "other",
#>         "name": "Other",
#>         "spdx_id": "NOASSERTION",
#>         "url": {},
#>         "node_id": "MDc6TGljZW5zZTA="
#>       }
#>     }
#>   ]
#> }

github_schema <- github_payload |>
    schema_infer(keys = "required", arrays = "rest") |>
    schema_compact()
github_schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "keys": {
#>     "type": "named",
#>     "must.include": ["total_count", "incomplete_results", "items"]
#>   },
#>   "fields": {
#>     "total_count": {
#>       "check": {
#>         "kind": "int"
#>       }
#>     },
#>     "incomplete_results": {
#>       "check": {
#>         "kind": "flag"
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
#>           "type": "named",
#>           "must.include": ["id", "node_id", "name", "full_name", "private", "html_url", "description", "fork", "created_at", "updated_at", "pushed_at", "size", "stargazers_count", "watchers_count", "language", "has_issues", "has_projects", "has_downloads", "has_wiki", "has_pages", "has_discussions", "forks_count", "archived", "disabled", "open_issues_count", "allow_forking", "is_template", "topics", "visibility", "default_branch", "score", "owner", "license"]
#>         },
#>         "fields": {
#>           "topics": {
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
#>           },
#>           "owner": {
#>             "check": {
#>               "kind": "list"
#>             },
#>             "keys": {
#>               "type": "named",
#>               "must.include": ["login", "id", "node_id", "html_url", "type", "site_admin"]
#>             },
#>             "fields": {
#>               "id": {
#>                 "check": {
#>                   "kind": "int"
#>                 }
#>               },
#>               "site_admin": {
#>                 "check": {
#>                   "kind": "flag"
#>                 }
#>               }
#>             },
#>             "groups": [
#>               {
#>                 "names": ["login", "node_id", "html_url", "type"],
#>                 "check": {
#>                   "kind": "string"
#>                 }
#>               }
#>             ]
#>           },
#>           "license": {
#>             "check": {
#>               "kind": "list"
#>             },
#>             "keys": {
#>               "type": "named",
#>               "must.include": ["key", "name", "spdx_id", "url", "node_id"]
#>             },
#>             "fields": {
#>               "url": {
#>                 "any": [
#>                   {
#>                     "check": {
#>                       "kind": "string"
#>                     }
#>                   },
#>                   {
#>                     "check": {
#>                       "kind": "null"
#>                     }
#>                   }
#>                 ]
#>               }
#>             },
#>             "groups": [
#>               {
#>                 "names": ["key", "name", "spdx_id", "node_id"],
#>                 "check": {
#>                   "kind": "string"
#>                 }
#>               }
#>             ]
#>           }
#>         },
#>         "groups": [
#>           {
#>             "names": ["id", "size", "stargazers_count", "watchers_count", "forks_count", "open_issues_count", "score"],
#>             "check": {
#>               "kind": "int"
#>             }
#>           },
#>           {
#>             "names": ["node_id", "name", "full_name", "html_url", "description", "created_at", "updated_at", "pushed_at", "language", "visibility", "default_branch"],
#>             "check": {
#>               "kind": "string"
#>             }
#>           },
#>           {
#>             "names": ["private", "fork", "has_issues", "has_projects", "has_downloads", "has_wiki", "has_pages", "has_discussions", "archived", "disabled", "allow_forking", "is_template"],
#>             "check": {
#>               "kind": "flag"
#>             }
#>           }
#>         ]
#>       }
#>     }
#>   }
#> }
```

The `items` field is inferred as an unnamed list whose `rest` schema
describes repository-like objects.

``` r

bad_github <- github_payload
bad_github$items[[1L]]$owner$id <- "not an integer"

github_schema |>
    schema_validate(github_payload, mode = "test")
#> [1] TRUE
github_schema |>
    schema_validate(bad_github, mode = "check", name = "github")
#> [1] "github$items[[1]]$owner$id: Must be of type 'single integerish value', not 'character'"
```

## CrossRef Works

For live CrossRef data:

``` r

crossref_payload <- jsonlite::fromJSON(
    "https://api.crossref.org/works?query.title=schema&rows=2",
    simplifyVector = FALSE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
)
```

Again, the runnable example uses a curated subset of a real saved
response.

``` r

crossref_payload <- jsonlite::fromJSON(
    payload_path("crossref-works.json"),
    simplifyVector = FALSE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
)
jsonlite::toJSON(crossref_payload, pretty = TRUE, auto_unbox = TRUE)
#> {
#>   "status": "ok",
#>   "message-type": "work-list",
#>   "message-version": "1.0.0",
#>   "message": {
#>     "total-results": 13146,
#>     "items-per-page": 2,
#>     "query": {
#>       "start-index": 0,
#>       "search-terms": {}
#>     },
#>     "items": [
#>       {
#>         "DOI": "10.33115/udg_bib/msr.v17i0.22300",
#>         "type": "journal-article",
#>         "publisher": "Edicions A Peticio",
#>         "title": "Schema saffico e schema zaglialesco",
#>         "container-title": "Mot so razo",
#>         "short-container-title": "MSR",
#>         "volume": "17",
#>         "ISSN": [
#>           "2385-4359",
#>           "1575-5568"
#>         ],
#>         "score": 15.4821,
#>         "URL": "https://doi.org/10.33115/udg_bib/msr.v17i0.22300",
#>         "reference-count": 0,
#>         "is-referenced-by-count": 0,
#>         "references-count": 0,
#>         "issued": {
#>           "date-parts": [
#>             [
#>               2019,
#>               9,
#>               5
#>             ]
#>           ]
#>         },
#>         "created": {
#>           "date-parts": [
#>             [
#>               2019,
#>               9,
#>               6
#>             ]
#>           ],
#>           "date-time": "2019-09-06T03:43:13Z",
#>           "timestamp": 1567741393000
#>         },
#>         "published": {
#>           "date-parts": [
#>             [
#>               2019,
#>               9,
#>               5
#>             ]
#>           ]
#>         },
#>         "published-online": {
#>           "date-parts": [
#>             [
#>               2019,
#>               9,
#>               5
#>             ]
#>           ]
#>         },
#>         "deposited": {
#>           "date-parts": [
#>             [
#>               2019,
#>               9,
#>               6
#>             ]
#>           ],
#>           "date-time": "2019-09-06T03:43:15Z",
#>           "timestamp": 1567741395000
#>         },
#>         "author": [
#>           {
#>             "given": "Lorenzo",
#>             "family": "Mainini",
#>             "sequence": "first",
#>             "affiliation": []
#>           }
#>         ],
#>         "link": [
#>           {
#>             "URL": "https://revistes.udg.edu/mot-so-razo/article/viewFile/22300/26052",
#>             "content-type": "application/pdf",
#>             "content-version": "vor",
#>             "intended-application": "text-mining"
#>           },
#>           {
#>             "URL": "https://revistes.udg.edu/mot-so-razo/article/viewFile/22300/26052",
#>             "content-type": "unspecified",
#>             "content-version": "vor",
#>             "intended-application": "similarity-checking"
#>           }
#>         ]
#>       },
#>       {
#>         "DOI": "10.5040/9780567678393.177",
#>         "type": "other",
#>         "publisher": "Bloomsbury Publishing Plc",
#>         "title": "Schema",
#>         "container-title": "The Dictionary of the Bible and Ancient Media",
#>         "ISBN": [
#>           "9780567678393",
#>           "9780567222497"
#>         ],
#>         "score": 15.337,
#>         "URL": "https://doi.org/10.5040/9780567678393.177",
#>         "reference-count": 0,
#>         "is-referenced-by-count": 0,
#>         "references-count": 0,
#>         "issued": {
#>           "date-parts": [
#>             2017
#>           ]
#>         },
#>         "created": {
#>           "date-parts": [
#>             [
#>               2020,
#>               2,
#>               28
#>             ]
#>           ],
#>           "date-time": "2020-02-28T14:26:46Z",
#>           "timestamp": 1582900006000
#>         },
#>         "published": {
#>           "date-parts": [
#>             2017
#>           ]
#>         },
#>         "published-print": {
#>           "date-parts": [
#>             2017
#>           ]
#>         },
#>         "deposited": {
#>           "date-parts": [
#>             [
#>               2020,
#>               9,
#>               2
#>             ]
#>           ],
#>           "date-time": "2020-09-02T18:28:58Z",
#>           "timestamp": 1599071338000
#>         }
#>       }
#>     ]
#>   }
#> }

crossref_schema <- crossref_payload |>
    schema_infer(keys = "named", arrays = "rest") |>
    schema_compact()
crossref_schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "keys": {
#>     "type": "named"
#>   },
#>   "fields": {
#>     "message": {
#>       "check": {
#>         "kind": "list"
#>       },
#>       "keys": {
#>         "type": "named"
#>       },
#>       "fields": {
#>         "query": {
#>           "check": {
#>             "kind": "list"
#>           },
#>           "keys": {
#>             "type": "named"
#>           },
#>           "fields": {
#>             "start-index": {
#>               "check": {
#>                 "kind": "int"
#>               }
#>             },
#>             "search-terms": {
#>               "check": {
#>                 "kind": "null"
#>               }
#>             }
#>           }
#>         },
#>         "items": {
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
#>               "type": "named"
#>             },
#>             "fields": {
#>               "score": {
#>                 "check": {
#>                   "kind": "number"
#>                 }
#>               },
#>               "published-online": {
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "named"
#>                 },
#>                 "fields": {
#>                   "date-parts": {
#>                     "check": {
#>                       "kind": "list"
#>                     },
#>                     "keys": {
#>                       "type": "unnamed"
#>                     },
#>                     "rest": {
#>                       "check": {
#>                         "kind": "list"
#>                       },
#>                       "keys": {
#>                         "type": "unnamed"
#>                       },
#>                       "rest": {
#>                         "check": {
#>                           "kind": "int"
#>                         }
#>                       }
#>                     }
#>                   }
#>                 }
#>               },
#>               "author": {
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "unnamed"
#>                 },
#>                 "rest": {
#>                   "check": {
#>                     "kind": "list"
#>                   },
#>                   "keys": {
#>                     "type": "named"
#>                   },
#>                   "fields": {
#>                     "affiliation": {
#>                       "check": {
#>                         "kind": "list"
#>                       },
#>                       "keys": {
#>                         "type": "unnamed"
#>                       }
#>                     }
#>                   },
#>                   "groups": [
#>                     {
#>                       "names": ["given", "family", "sequence"],
#>                       "check": {
#>                         "kind": "string"
#>                       }
#>                     }
#>                   ]
#>                 }
#>               },
#>               "link": {
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "unnamed"
#>                 },
#>                 "rest": {
#>                   "check": {
#>                     "kind": "list"
#>                   },
#>                   "keys": {
#>                     "type": "named"
#>                   },
#>                   "groups": [
#>                     {
#>                       "names": ["URL", "content-type", "content-version", "intended-application"],
#>                       "check": {
#>                         "kind": "string"
#>                       }
#>                     }
#>                   ]
#>                 }
#>               },
#>               "published-print": {
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "named"
#>                 },
#>                 "fields": {
#>                   "date-parts": {
#>                     "check": {
#>                       "kind": "list"
#>                     },
#>                     "keys": {
#>                       "type": "unnamed"
#>                     },
#>                     "rest": {
#>                       "check": {
#>                         "kind": "int"
#>                       }
#>                     }
#>                   }
#>                 }
#>               }
#>             },
#>             "groups": [
#>               {
#>                 "names": ["DOI", "type", "publisher", "title", "container-title", "short-container-title", "volume", "URL"],
#>                 "check": {
#>                   "kind": "string"
#>                 }
#>               },
#>               {
#>                 "names": ["ISSN", "ISBN"],
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "unnamed"
#>                 },
#>                 "rest": {
#>                   "check": {
#>                     "kind": "string"
#>                   }
#>                 }
#>               },
#>               {
#>                 "names": ["reference-count", "is-referenced-by-count", "references-count"],
#>                 "check": {
#>                   "kind": "int"
#>                 }
#>               },
#>               {
#>                 "names": ["issued", "published"],
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "named"
#>                 },
#>                 "fields": {
#>                   "date-parts": {
#>                     "check": {
#>                       "kind": "list"
#>                     },
#>                     "keys": {
#>                       "type": "unnamed"
#>                     },
#>                     "rest": {
#>                       "any": [
#>                         {
#>                           "check": {
#>                             "kind": "list"
#>                           },
#>                           "keys": {
#>                             "type": "unnamed"
#>                           },
#>                           "rest": {
#>                             "check": {
#>                               "kind": "int"
#>                             }
#>                           }
#>                         },
#>                         {
#>                           "check": {
#>                             "kind": "int"
#>                           }
#>                         }
#>                       ]
#>                     }
#>                   }
#>                 }
#>               },
#>               {
#>                 "names": ["created", "deposited"],
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "named"
#>                 },
#>                 "fields": {
#>                   "date-parts": {
#>                     "check": {
#>                       "kind": "list"
#>                     },
#>                     "keys": {
#>                       "type": "unnamed"
#>                     },
#>                     "rest": {
#>                       "check": {
#>                         "kind": "list"
#>                       },
#>                       "keys": {
#>                         "type": "unnamed"
#>                       },
#>                       "rest": {
#>                         "check": {
#>                           "kind": "int"
#>                         }
#>                       }
#>                     }
#>                   },
#>                   "date-time": {
#>                     "check": {
#>                       "kind": "string"
#>                     }
#>                   },
#>                   "timestamp": {
#>                     "check": {
#>                       "kind": "number"
#>                     }
#>                   }
#>                 }
#>               }
#>             ]
#>           }
#>         }
#>       },
#>       "groups": [
#>         {
#>           "names": ["total-results", "items-per-page"],
#>           "check": {
#>             "kind": "int"
#>           }
#>         }
#>       ]
#>     }
#>   },
#>   "groups": [
#>     {
#>       "names": ["status", "message-type", "message-version"],
#>       "check": {
#>         "kind": "string"
#>       }
#>     }
#>   ]
#> }
```

CrossRef `date-parts` is a tuple-like array. Inference records the
observed array shape, then a small manual edit can express
year/month/day positions for the saved response’s `published-online`
date.

The path below walks through the inferred homogeneous arrays. The first
`rest` means “the schema for each item”; the final `rest` means “the
schema for each date-parts entry”.

``` text
$message$items$rest$`published-online`$`date-parts`$rest
```

``` r

date_part <- list(
    check = list(kind = "list", min.len = 1L, max.len = 3L),
    keys = list(type = "unnamed"),
    positions = list(
        schema_check("int", lower = 0),
        schema_check("int", lower = 1, upper = 12),
        schema_check("int", lower = 1, upper = 31)
    )
)

crossref_schema <- crossref_schema |>
    schema_replace("$message$items$rest$`published-online`$`date-parts`$rest", date_part)
crossref_schema
#> {
#>   "check": {
#>     "kind": "list"
#>   },
#>   "keys": {
#>     "type": "named"
#>   },
#>   "fields": {
#>     "message": {
#>       "check": {
#>         "kind": "list"
#>       },
#>       "keys": {
#>         "type": "named"
#>       },
#>       "fields": {
#>         "query": {
#>           "check": {
#>             "kind": "list"
#>           },
#>           "keys": {
#>             "type": "named"
#>           },
#>           "fields": {
#>             "start-index": {
#>               "check": {
#>                 "kind": "int"
#>               }
#>             },
#>             "search-terms": {
#>               "check": {
#>                 "kind": "null"
#>               }
#>             }
#>           }
#>         },
#>         "items": {
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
#>               "type": "named"
#>             },
#>             "fields": {
#>               "score": {
#>                 "check": {
#>                   "kind": "number"
#>                 }
#>               },
#>               "published-online": {
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "named"
#>                 },
#>                 "fields": {
#>                   "date-parts": {
#>                     "check": {
#>                       "kind": "list"
#>                     },
#>                     "keys": {
#>                       "type": "unnamed"
#>                     },
#>                     "rest": {
#>                       "check": {
#>                         "kind": "list",
#>                         "min.len": 1,
#>                         "max.len": 3
#>                       },
#>                       "keys": {
#>                         "type": "unnamed"
#>                       },
#>                       "positions": [
#>                         {
#>                           "check": {
#>                             "kind": "int",
#>                             "lower": 0
#>                           }
#>                         },
#>                         {
#>                           "check": {
#>                             "kind": "int",
#>                             "lower": 1,
#>                             "upper": 12
#>                           }
#>                         },
#>                         {
#>                           "check": {
#>                             "kind": "int",
#>                             "lower": 1,
#>                             "upper": 31
#>                           }
#>                         }
#>                       ]
#>                     }
#>                   }
#>                 }
#>               },
#>               "author": {
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "unnamed"
#>                 },
#>                 "rest": {
#>                   "check": {
#>                     "kind": "list"
#>                   },
#>                   "keys": {
#>                     "type": "named"
#>                   },
#>                   "fields": {
#>                     "affiliation": {
#>                       "check": {
#>                         "kind": "list"
#>                       },
#>                       "keys": {
#>                         "type": "unnamed"
#>                       }
#>                     }
#>                   },
#>                   "groups": [
#>                     {
#>                       "names": ["given", "family", "sequence"],
#>                       "check": {
#>                         "kind": "string"
#>                       }
#>                     }
#>                   ]
#>                 }
#>               },
#>               "link": {
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "unnamed"
#>                 },
#>                 "rest": {
#>                   "check": {
#>                     "kind": "list"
#>                   },
#>                   "keys": {
#>                     "type": "named"
#>                   },
#>                   "groups": [
#>                     {
#>                       "names": ["URL", "content-type", "content-version", "intended-application"],
#>                       "check": {
#>                         "kind": "string"
#>                       }
#>                     }
#>                   ]
#>                 }
#>               },
#>               "published-print": {
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "named"
#>                 },
#>                 "fields": {
#>                   "date-parts": {
#>                     "check": {
#>                       "kind": "list"
#>                     },
#>                     "keys": {
#>                       "type": "unnamed"
#>                     },
#>                     "rest": {
#>                       "check": {
#>                         "kind": "int"
#>                       }
#>                     }
#>                   }
#>                 }
#>               }
#>             },
#>             "groups": [
#>               {
#>                 "names": ["DOI", "type", "publisher", "title", "container-title", "short-container-title", "volume", "URL"],
#>                 "check": {
#>                   "kind": "string"
#>                 }
#>               },
#>               {
#>                 "names": ["ISSN", "ISBN"],
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "unnamed"
#>                 },
#>                 "rest": {
#>                   "check": {
#>                     "kind": "string"
#>                   }
#>                 }
#>               },
#>               {
#>                 "names": ["reference-count", "is-referenced-by-count", "references-count"],
#>                 "check": {
#>                   "kind": "int"
#>                 }
#>               },
#>               {
#>                 "names": ["issued", "published"],
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "named"
#>                 },
#>                 "fields": {
#>                   "date-parts": {
#>                     "check": {
#>                       "kind": "list"
#>                     },
#>                     "keys": {
#>                       "type": "unnamed"
#>                     },
#>                     "rest": {
#>                       "any": [
#>                         {
#>                           "check": {
#>                             "kind": "list"
#>                           },
#>                           "keys": {
#>                             "type": "unnamed"
#>                           },
#>                           "rest": {
#>                             "check": {
#>                               "kind": "int"
#>                             }
#>                           }
#>                         },
#>                         {
#>                           "check": {
#>                             "kind": "int"
#>                           }
#>                         }
#>                       ]
#>                     }
#>                   }
#>                 }
#>               },
#>               {
#>                 "names": ["created", "deposited"],
#>                 "check": {
#>                   "kind": "list"
#>                 },
#>                 "keys": {
#>                   "type": "named"
#>                 },
#>                 "fields": {
#>                   "date-parts": {
#>                     "check": {
#>                       "kind": "list"
#>                     },
#>                     "keys": {
#>                       "type": "unnamed"
#>                     },
#>                     "rest": {
#>                       "check": {
#>                         "kind": "list"
#>                       },
#>                       "keys": {
#>                         "type": "unnamed"
#>                       },
#>                       "rest": {
#>                         "check": {
#>                           "kind": "int"
#>                         }
#>                       }
#>                     }
#>                   },
#>                   "date-time": {
#>                     "check": {
#>                       "kind": "string"
#>                     }
#>                   },
#>                   "timestamp": {
#>                     "check": {
#>                       "kind": "number"
#>                     }
#>                   }
#>                 }
#>               }
#>             ]
#>           }
#>         }
#>       },
#>       "groups": [
#>         {
#>           "names": ["total-results", "items-per-page"],
#>           "check": {
#>             "kind": "int"
#>           }
#>         }
#>       ]
#>     }
#>   },
#>   "groups": [
#>     {
#>       "names": ["status", "message-type", "message-version"],
#>       "check": {
#>         "kind": "string"
#>       }
#>     }
#>   ]
#> }

bad_crossref <- crossref_payload
bad_crossref$message$items[[1L]]$`published-online`$`date-parts`[[1L]][[2L]] <- 13L

crossref_schema |>
    schema_validate(crossref_payload, mode = "test")
#> [1] TRUE
crossref_schema |>
    schema_validate(bad_crossref, mode = "check", name = "crossref")
#> [1] "crossref$message$items[[1]]$published-online$date-parts[[1]][[2]]: Element 1 is not <= 12"
```

When a reusable component has a clear domain name, author it explicitly
with `$defs` and `$ref`.
[`schema_compact()`](https://hongyuanjia.github.io/schemate/reference/schema_compact.md)
deliberately avoids inventing reusable definition names for you.
