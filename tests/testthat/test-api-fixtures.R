api_fixture_path <- function(file) {
    path <- system.file("extdata", "api", file, package = "schemate")
    if (nzchar(path)) {
        return(path)
    }

    test_path("..", "..", "inst", "extdata", "api", file)
}

read_api_fixture <- function(file) {
    jsonlite::fromJSON(
        api_fixture_path(file),
        simplifyVector = FALSE,
        simplifyDataFrame = FALSE,
        simplifyMatrix = FALSE
    )
}

test_that("GitHub API fixture supports infer compact validate workflow", {
    payload <- read_api_fixture("github-search-repositories.json")
    schema <- schema_compact(schema_infer(payload, keys = "named", arrays = "rest"))
    round_trip <- schema_doc(as.list(schema))

    bad <- payload
    bad$items[[1L]]$owner$id <- "not an integer"

    expect_true(length(payload$items) >= 2L)
    expect_true(schema_validate(schema, payload, mode = "test"))
    expect_match(
        schema_validate(schema, bad, mode = "check", name = "github"),
        "github\\$items\\[\\[1\\]\\]\\$owner\\$id"
    )
    expect_equal(as.list(round_trip), as.list(schema))
})

test_that("CrossRef API fixture supports infer compact edit validate workflow", {
    payload <- read_api_fixture("crossref-works.json")
    schema <- schema_compact(schema_infer(payload, keys = "named", arrays = "rest"))

    date_part <- schema_any(
        schema_check("int", lower = 0),
        list(
            check = list(kind = "list", min.len = 1L, max.len = 3L),
            keys = list(type = "unnamed"),
            positions = list(
                schema_check("int", lower = 0),
                schema_check("int", lower = 1, upper = 12),
                schema_check("int", lower = 1, upper = 31)
            )
        )
    )
    schema <- schema_add_def(schema, "crossref_date_part", date_part)
    paths <- schema_find(schema, schema_where_path("(^|\\$)`date-parts`\\$rest$"))
    schema <- schema_replace_where(
        schema,
        schema_where_path("(^|\\$)`date-parts`\\$rest$"),
        schema_ref("crossref_date_part")
    )
    round_trip <- schema_doc(as.list(schema))

    expect_true(length(payload$message$items) >= 2L)
    expect_true(length(paths) >= 2L)
    expect_true(schema_validate(schema, payload, mode = "test"))

    bad <- unserialize(serialize(payload, NULL))
    bad$message$items[[1L]]$`published-online`$`date-parts`[[1L]][[2L]] <- 13L
    expect_match(
        schema_validate(schema, bad, mode = "check", name = "crossref"),
        "crossref\\$message\\$items\\[\\[1\\]\\]\\$published-online\\$date-parts"
    )
    expect_equal(as.list(round_trip), as.list(schema))
})
