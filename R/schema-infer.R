#' @include schema-doc.R
#' @noRd
NULL

#' Infer a conservative schema from example data
#'
#' `schema_infer()` builds a `SchemaDoc` from example data using conservative,
#' structural inference only. It infers base/container check kinds and nested
#' field structure, but does not guess higher-level authoring constructs such as
#' `$defs`, `$ref`, `keys`, `groups`, or combinators.
#'
#' To parse an existing schema DSL document, use `schema_doc()` or
#' `schema_read()` instead.
#'
#' @param x Example data to infer from.
#' @param version Optional schema document version string.
#' @param keys Strategy for inferring optional `keys` rules from observed names.
#'   Use `"none"` to skip names-rule inference, `"named"` to require named
#'   inputs, `"required"` to require the observed names to be present, or
#'   `"exact"` to require the observed names in the observed order.
#'
#' @return A `SchemaDoc` inferred from `x`.
#' @export
schema_infer <- function(x, version = NULL, keys = c("none", "named", "required", "exact")) {
    checkmate::assert_string(version, null.ok = TRUE)
    keys <- checkmate::matchArg(keys, c("none", "named", "required", "exact"))

    if (S7::S7_inherits(x, SchemaDoc)) {
        if (!is.null(version) || !identical(keys, "none")) {
            stop("`version` and `keys` cannot be supplied when `x` is already a `SchemaDoc`.", call. = FALSE)
        }
        return(x)
    }

    root <- schema_infer__node(x, keys = keys)
    doc <- list()
    if (!is.null(version)) {
        doc$version <- version
    }
    doc <- c(doc, root)

    schema_doc(doc)
}

schema_infer__kind <- function(kind, label = kind) {
    if (!kind %in% SCHEMA_SPEC_KINDS) {
        stop(
            sprintf(
                "`schema_infer()` cannot infer `%s` because check kind `%s` is not supported.",
                label,
                kind
            ),
            call. = FALSE
        )
    }

    kind
}

schema_infer__keys_rule <- function(x, keys) {
    if (identical(keys, "none") || !schema_infer__has_named_elements(x)) {
        return(NULL)
    }

    nms <- names(x)
    switch(
        keys,
        named = list(type = "named"),
        required = list(type = "named", must.include = nms),
        exact = list(identical.to = nms),
        NULL
    )
}

schema_infer__check_node <- function(kind, fields = NULL, keys_rule = NULL) {
    out <- list(check = list(kind = schema_infer__kind(kind)))
    if (!is.null(keys_rule) && length(keys_rule)) {
        out$keys <- keys_rule
    }
    if (!is.null(fields) && length(fields)) {
        out$fields <- fields
    }
    out
}

schema_infer__has_named_elements <- function(x) {
    length(x) > 0L && isTRUE(checkmate::check_names(names(x), type = "named"))
}

schema_infer__fields <- function(x, keys) {
    if (!schema_infer__has_named_elements(x)) {
        return(NULL)
    }

    nms <- names(x)
    stats::setNames(lapply(nms, function(name) schema_infer__node(x[[name]], keys = keys)), nms)
}

schema_infer__atomic_kind <- function(x) {
    if (inherits(x, "Date")) {
        return(schema_infer__kind("date", label = class(x)[[1L]]))
    }

    if (inherits(x, "POSIXct")) {
        return(schema_infer__kind("POSIXct", label = class(x)[[1L]]))
    }

    if (is.factor(x)) {
        return(schema_infer__kind("factor"))
    }

    if (is.logical(x)) {
        return(schema_infer__kind(if (length(x) == 1L && !is.na(x)) "flag" else "logical"))
    }

    if (is.integer(x)) {
        return(schema_infer__kind(if (length(x) == 1L && !is.na(x)) "int" else "integer"))
    }

    if (is.double(x)) {
        return(schema_infer__kind(if (length(x) == 1L && !is.na(x)) "number" else "numeric"))
    }

    if (is.character(x)) {
        return(schema_infer__kind(if (length(x) == 1L && !is.na(x)) "string" else "character"))
    }

    if (is.complex(x)) {
        return(schema_infer__kind("complex"))
    }

    if (is.raw(x)) {
        return(schema_infer__kind("raw"))
    }

    NULL
}

schema_infer__node <- function(x, keys = "none") {
    if (inherits(x, "data.table")) {
        return(schema_infer__check_node(
            "data_table",
            fields = schema_infer__fields(x, keys = keys),
            keys_rule = schema_infer__keys_rule(x, keys)
        ))
    }

    if (inherits(x, c("tbl_df", "tbl"))) {
        return(schema_infer__check_node(
            "tibble",
            fields = schema_infer__fields(x, keys = keys),
            keys_rule = schema_infer__keys_rule(x, keys)
        ))
    }

    if (is.data.frame(x)) {
        return(schema_infer__check_node(
            "data_frame",
            fields = schema_infer__fields(x, keys = keys),
            keys_rule = schema_infer__keys_rule(x, keys)
        ))
    }

    if (is.null(x)) {
        return(schema_infer__check_node("null"))
    }

    if (is.list(x)) {
        return(schema_infer__check_node(
            "list",
            fields = schema_infer__fields(x, keys = keys),
            keys_rule = schema_infer__keys_rule(x, keys)
        ))
    }

    atomic_kind <- schema_infer__atomic_kind(x)
    if (!is.null(atomic_kind)) {
        return(schema_infer__check_node(atomic_kind, keys_rule = schema_infer__keys_rule(x, keys)))
    }

    stop(
        sprintf(
            paste(
                "`schema_infer()` does not support objects of class {%s}.",
                "Please construct the schema manually with authoring helpers."
            ),
            paste(class(x), collapse = ", ")
        ),
        call. = FALSE
    )
}

# vim: fdm=marker :
