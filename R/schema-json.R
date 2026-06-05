#' @include schema-doc.R
schema_json__read_json <- function(txt) {
    schema_utils__require_namespace("jsonlite", "read schema JSON")
    jsonlite::fromJSON(txt, simplifyVector = TRUE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE)
}

#' Read and write schema JSON
#'
#' `schema_read()` reads schema JSON into a `SchemaDoc`. `schema_write()`
#' serializes schema objects to schema JSON. Both functions require the
#' suggested package `jsonlite`.
#'
#' @param txt JSON text, local file path, or URL accepted by
#'   `jsonlite::fromJSON()`.
#' @param x A schema object accepted by `as.list()`, usually a `SchemaDoc`.
#' @param path Output file path.
#' @param overwrite Whether an existing output file may be overwritten.
#' @param pretty Whether JSON output should be pretty-printed.
#' @param auto_unbox Passed to `jsonlite::write_json()`.
#'
#' @return `schema_read()` returns a `SchemaDoc`. `schema_write()` invisibly
#'   returns `path`.
#'
#' @examples
#' schema <- schema_infer(list(id = 1L))
#' schema
#'
#' path <- tempfile(fileext = ".json")
#' schema_write(schema, path)
#'
#' schema_read(path)
#'
#' @rdname schema-json
#' @export
schema_write <- function(x, path, overwrite = FALSE, pretty = TRUE, auto_unbox = TRUE) {
    schema_utils__require_namespace("jsonlite", "write schema JSON")
    checkmate::assert_string(path, min.chars = 1L)
    checkmate::assert_flag(overwrite)
    if (!overwrite && file.exists(path)) {
        stop(sprintf("File already exists: %s", path), call. = FALSE)
    }

    jsonlite::write_json(
        as.list(x),
        path,
        pretty = pretty,
        auto_unbox = auto_unbox,
        null = "null",
        na = "null"
    )

    invisible(path)
}

#' @rdname schema-json
#' @export
schema_read <- function(txt) {
    json <- schema_json__read_json(txt)
    path <- NULL
    if (checkmate::test_string(txt) && !jsonlite::validate(txt)) {
        if (grepl("^https?://", txt, useBytes = TRUE) || file.exists(txt)) {
            path <- txt
        }
    }
    schema_doc(json, path)
}
# vim: fdm=marker :
