#' @include schema-utils.R
#' @include schema-spec.R

# SchemaDoc {{{
SchemaDoc <- S7::new_class(
    "SchemaDoc",
    parent = SchemaSpec,
    properties = list(
        version = schema_utils__prop_string(null.ok = TRUE),
        path = schema_utils__prop_string(),
        root = S7::new_property(SchemaNode),
        defs = schema_utils__prop_list("SchemaNode")
    )
)
# }}}

# schema_doc {{{
schema_doc__defs <- function(x, path = "$`$defs`") {
    if (!length(x)) {
        return(stats::setNames(list(), character()))
    }

    schema_spec__assert_list(path, "'$defs'", x, types = "list", names = "unique")
    nms <- names(x)
    if (any(grepl("/", nms, fixed = TRUE))) {
        schema_spec__error(path, "'$defs': Names must not contain '/'.")
    }

    stats::setNames(
        lapply(nms, function(name) {
            schema_spec__node(
                x[[name]],
                path = sprintf("%s[['%s']]", path, name),
                defs = nms,
                root = FALSE
            )
        }),
        nms
    )
}

#' Parse schema documents
#'
#' `schema_doc()` parses a schema DSL list into a schemate schema document
#' object.
#'
#' Normal users usually create schema documents with `schema_infer()`,
#' `schema_read()`, or the edit helpers. Use `schema_doc()` when you are
#' hand-authoring a schema as an R list.
#'
#' @param x A schema DSL list or an existing schemate schema document.
#' @param path Optional source path stored as runtime metadata.
#'
#' @return A schemate schema document object.
#'
#' @examples
#' doc <- schema_doc(list(check = list(kind = "string", min.chars = 1)))
#' doc
#'
#' schema_validate(doc, "ok")
#'
#' @export
schema_doc <- function(x, path = NULL) {
    if (S7::S7_inherits(x, SchemaDoc)) {
        return(x)
    }

    schema_spec__assert_list("$", "schema document", x, names = "unique")
    schema_spec__assert_names("$", "schema document", x, subset.of = SCHEMA_SPEC_KEYWORDS)

    defs <- schema_doc__defs(x$`$defs`)

    root <- x[!names(x) %in% c("$defs", "version")]
    if (!length(root)) {
        schema_spec__error("$", "'root': Schema document must contain a root schema node.")
    }

    SchemaDoc(
        path = path,
        version = x$version,
        root = schema_spec__node(root, path = "$", defs = names(defs), root = TRUE),
        defs = defs
    )
}
# }}}

# as.list.SchemaDoc {{{
S7::method(as.list, SchemaDoc) <- function(x, ...) {
    # Top-level serialization contract for SchemaDoc:
    # 1. `version` first when present
    # 2. root `description` next when present
    # 3. `$defs` next when present
    # 4. serialized root operator-specific entries last
    # `path` is runtime metadata and is intentionally excluded.
    out <- list()
    root <- as.list(x@root)

    if (!is.null(x@version)) {
        out$version <- x@version
    }

    if ("description" %in% names(root)) {
        out$description <- root$description
        root$description <- NULL
    }

    if (length(x@defs)) {
        defs <- stats::setNames(lapply(x@defs, as.list), names(x@defs))
        out$`$defs` <- defs
    }

    out <- c(out, root)

    out
}
# }}}

# vim: fdm=marker :
