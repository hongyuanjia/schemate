# API Examples

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

``` r

library(schemate)

payload_path <- function(file) {
  path <- system.file("extdata/api", file, package = "schemate")
  if (nzchar(path)) {
    return(path)
  }

  file.path("..", "inst", "extdata", "api", file)
}
```

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

github_schema <- github_payload |>
  schema_infer(keys = "named", arrays = "rest") |>
  schema_compact()

github_items <- as.list(github_schema)$fields$items
github_items$keys
#> $type
#> [1] "unnamed"
names(github_items$rest$fields)
#> [1] "topics"  "owner"   "license"
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

crossref_schema <- crossref_payload |>
  schema_infer(keys = "named", arrays = "rest") |>
  schema_compact()

crossref_items <- as.list(crossref_schema)$fields$message$fields$items
crossref_items$keys
#> $type
#> [1] "unnamed"
names(crossref_items$rest$fields)
#> [1] "score"            "published-online" "author"           "link"            
#> [5] "published-print"
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
