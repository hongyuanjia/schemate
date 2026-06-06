# schema_validate {{{
#' Validate input against a schema
#'
#' `schema_validate()` validates an R object against a `SchemaDoc`,
#' `SchemaFlat`, or compiled flat schema node. When validating many inputs
#' against the same schema, compile it once with [schema_compile()] and reuse
#' the compiled schema.
#'
#' @param schema A `SchemaDoc`, `SchemaFlat`, or compiled flat schema node.
#' @param x Input object to validate.
#' @param mode One of `"assert"`, `"check"`, `"test"`, or `"expect"`.
#' @param name Optional display name used in validation messages.
#' @param ... Reserved for future extension.
#'
#' @return In `"assert"` mode, invisibly returns `x` or throws an error. In
#'   `"check"` mode, returns `TRUE` or a diagnostic string. In `"test"` mode,
#'   returns `TRUE` or `FALSE`. In `"expect"` mode, returns a testthat-style
#'   expectation object.
#'
#' @examples
#' schema <- schema_doc(list(
#'     check = list(kind = "list"),
#'     fields = list(id = list(check = list(kind = "int", lower = 1)))
#' ))
#' schema
#'
#' schema_validate(schema, list(id = 1L), mode = "test")
#' schema_validate(schema, list(id = 0L), mode = "check", name = "payload")
#'
#' compiled <- schema_compile(schema)
#' schema_validate(compiled, list(id = 2L), mode = "test")
#'
#' @export
schema_validate <- S7::new_generic(
    "schema_validate",
    "schema",
    function(schema, x, mode = "assert", name = NULL, ...) S7::S7_dispatch()
)

schema_validate__or <- function(x, y) {
    if (is.null(x)) y else x
}

schema_validate__make_expectation <- function(ok, message = NULL) {
    structure(
        list(
            message = schema_validate__or(message, if (ok) "Validation passed." else "Validation failed."),
            srcref = NULL,
            trace = NULL,
            passed = ok
        ),
        class = if (ok) {
            c("expectation_success", "expectation", "condition")
        } else {
            c("expectation_failure", "expectation", "error", "condition")
        }
    )
}

schema_validate__prefix_message <- function(result, path) {
    if (isTRUE(result)) {
        return(TRUE)
    }

    sprintf("%s: %s", path, result)
}

schema_validate__call_check <- function(fun, x, args = list()) {
    do.call(fun, c(list(x), args))
}

schema_validate__field_path <- function(path, key) {
    paste0(path, "$", key)
}

schema_validate__item_path <- function(path, i) {
    sprintf("%s[[%d]]", path, i)
}

schema_validate__keys_type <- function(schema) {
    if (is.null(schema@name)) {
        return(NULL)
    }

    schema@name@args$type
}

schema_validate__container_has_keyed_children <- function(schema) {
    length(schema@exact) ||
        length(schema@patterns) ||
        !is.null(schema@rest)
}

schema_validate__rule <- function(value, x, path) {
    schema_validate__prefix_message(
        schema_validate__call_check(
            schema_utils__checkmate_fun(value@kind),
            x,
            args = value@args
        ),
        path
    )
}

schema_validate__names_rule <- function(value, x, path) {
    schema_validate__prefix_message(
        schema_validate__call_check(checkmate::check_names, names(x), args = value@args),
        path
    )
}

schema_validate__impl <- S7::new_generic(
    "schema_validate__impl",
    "schema",
    function(schema, x, path) S7::S7_dispatch()
)

S7::method(schema_validate__impl, SchemaNodeLeaf) <- function(schema, x, path) {
    res <- schema_validate__rule(schema@value, x, path)
    if (!isTRUE(res)) {
        return(res)
    }

    if (!is.null(schema@name)) {
        return(schema_validate__names_rule(schema@name, x, path))
    }

    TRUE
}

S7::method(schema_validate__impl, SchemaNodeContainerFlat) <- function(schema, x, path) {
    res <- schema_validate__rule(schema@value, x, path)
    if (!isTRUE(res)) {
        return(res)
    }

    if (!is.null(schema@name)) {
        res <- schema_validate__names_rule(schema@name, x, path)
        if (!isTRUE(res)) {
            return(res)
        }
    }

    if (identical(schema_validate__keys_type(schema), "unnamed")) {
        if (length(schema@exact) || length(schema@patterns)) {
            return(sprintf("%s cannot use named field constraints with `keys$type = 'unnamed'`.", path))
        }

        n_positions <- length(schema@positions)
        n_present <- min(length(x), n_positions)

        if (n_present) {
            for (i in seq_len(n_present)) {
                res <- schema_validate__impl(schema@positions[[i]], x[[i]], schema_validate__item_path(path, i))
                if (!isTRUE(res)) {
                    return(res)
                }
            }
        }

        if (length(x) <= n_positions) {
            return(TRUE)
        }

        extra <- seq.int(n_positions + 1L, length(x))
        if (is.null(schema@rest)) {
            return(TRUE)
        }

        for (i in extra) {
            res <- schema_validate__impl(schema@rest, x[[i]], schema_validate__item_path(path, i))
            if (!isTRUE(res)) {
                return(res)
            }
        }

        return(TRUE)
    }

    raw_names <- names(x)
    if (length(x) && is.null(schema@name) && schema_validate__container_has_keyed_children(schema)) {
        if (!checkmate::test_character(raw_names, null.ok = FALSE, any.missing = FALSE, min.chars = 1L)) {
            return(sprintf(
                "%s must be a named object because this schema declares keyed child constraints.",
                path
            ))
        }
    }

    present <- schema_validate__or(raw_names, character())
    declared <- schema_flat__binding_names(schema@exact)
    present_pos <- match(declared, present, nomatch = 0L)

    for (i in seq_along(schema@exact)) {
        pos <- present_pos[[i]]
        if (!pos) {
            next
        }

        binding <- schema@exact[[i]]
        nm <- declared[[i]]
        res <- schema_validate__impl(binding@target, x[[pos]], schema_validate__field_path(path, nm))
        if (!isTRUE(res)) {
            return(res)
        }
    }

    extra <- setdiff(present, declared)
    pattern_matched <- character()
    for (nm in extra) {
        matched <- Filter(function(binding) grepl(binding@pattern, nm), schema@patterns)
        if (!length(matched)) {
            next
        }

        pattern_matched <- c(pattern_matched, nm)
        for (binding in matched) {
            res <- schema_validate__impl(binding@target, x[[nm]], schema_validate__field_path(path, nm))
            if (!isTRUE(res)) {
                return(res)
            }
        }
    }

    extra <- setdiff(extra, pattern_matched)
    if (!length(extra)) {
        return(TRUE)
    }

    if (is.null(schema@rest)) {
        return(TRUE)
    }

    for (nm in extra) {
        res <- schema_validate__impl(schema@rest, x[[nm]], schema_validate__field_path(path, nm))
        if (!isTRUE(res)) {
            return(res)
        }
    }

    TRUE
}

S7::method(schema_validate__impl, SchemaNodeAllFlat) <- function(schema, x, path) {
    for (branch in schema@branches) {
        res <- schema_validate__impl(branch, x, path)
        if (!isTRUE(res)) {
            return(res)
        }
    }

    TRUE
}

S7::method(schema_validate__impl, SchemaNodeAnyFlat) <- function(schema, x, path) {
    msgs <- character()
    for (i in seq_along(schema@branches)) {
        branch <- schema@branches[[i]]
        res <- schema_validate__impl(branch, x, path)
        if (isTRUE(res)) {
            return(TRUE)
        }
        msgs <- c(msgs, sprintf("[%d] %s", i, res))
    }

    sprintf("%s failed all branches of `any`: %s", path, paste(msgs, collapse = " | "))
}

S7::method(schema_validate__impl, SchemaNodeOneFlat) <- function(schema, x, path) {
    ok <- 0L
    msgs <- character()
    for (i in seq_along(schema@branches)) {
        branch <- schema@branches[[i]]
        res <- schema_validate__impl(branch, x, path)
        if (isTRUE(res)) {
            ok <- ok + 1L
        } else {
            msgs <- c(msgs, sprintf("[%d] %s", i, res))
        }
    }

    if (ok == 1L) {
        return(TRUE)
    }
    if (ok == 0L) {
        return(sprintf("%s matched no branches of `one`: %s", path, paste(msgs, collapse = " | ")))
    }

    sprintf("%s matched multiple branches of `one` (%d).", path, ok)
}

S7::method(schema_validate__impl, SchemaNodeNotFlat) <- function(schema, x, path) {
    res <- schema_validate__impl(schema@branch, x, path)
    if (isTRUE(res)) {
        return(sprintf("%s: `not` branch matched.", path))
    }

    TRUE
}

S7::method(schema_validate__impl, SchemaNode) <- function(schema, x, path) {
    stop("unsupported compiled schema node.", call. = FALSE)
}

S7::method(schema_validate__impl, S7::class_any) <- function(schema, x, path) {
    stop("unsupported compiled schema node.", call. = FALSE)
}

schema_validate__dispatch <- function(result, x, mode) {
    checkmate::assert_choice(mode, c("assert", "check", "test", "expect"))

    if (identical(mode, "check")) {
        return(result)
    }
    if (identical(mode, "test")) {
        return(isTRUE(result))
    }
    if (identical(mode, "expect")) {
        return(schema_validate__make_expectation(isTRUE(result), if (isTRUE(result)) NULL else result))
    }

    if (isTRUE(result)) {
        return(invisible(x))
    }
    stop(result, call. = FALSE)
}

S7::method(schema_validate, SchemaFlat) <- function(schema, x, mode = "assert", name = NULL, ...) {
    if (is.null(name)) {
        name <- deparse(substitute(x))
    }
    schema_validate__dispatch(schema_validate__impl(schema@root, x, name), x, mode)
}

S7::method(schema_validate, SchemaNodeLeaf) <- function(schema, x, mode = "assert", name = NULL, ...) {
    if (is.null(name)) {
        name <- deparse(substitute(x))
    }
    schema_validate__dispatch(schema_validate__impl(schema, x, name), x, mode)
}

S7::method(schema_validate, SchemaNodeContainerFlat) <- function(schema, x, mode = "assert", name = NULL, ...) {
    if (is.null(name)) {
        name <- deparse(substitute(x))
    }
    schema_validate__dispatch(schema_validate__impl(schema, x, name), x, mode)
}

S7::method(schema_validate, SchemaNodeAllFlat) <- function(schema, x, mode = "assert", name = NULL, ...) {
    if (is.null(name)) {
        name <- deparse(substitute(x))
    }
    schema_validate__dispatch(schema_validate__impl(schema, x, name), x, mode)
}

S7::method(schema_validate, SchemaNodeAnyFlat) <- function(schema, x, mode = "assert", name = NULL, ...) {
    if (is.null(name)) {
        name <- deparse(substitute(x))
    }
    schema_validate__dispatch(schema_validate__impl(schema, x, name), x, mode)
}

S7::method(schema_validate, SchemaNodeOneFlat) <- function(schema, x, mode = "assert", name = NULL, ...) {
    if (is.null(name)) {
        name <- deparse(substitute(x))
    }
    schema_validate__dispatch(schema_validate__impl(schema, x, name), x, mode)
}

S7::method(schema_validate, SchemaNodeNotFlat) <- function(schema, x, mode = "assert", name = NULL, ...) {
    if (is.null(name)) {
        name <- deparse(substitute(x))
    }
    schema_validate__dispatch(schema_validate__impl(schema, x, name), x, mode)
}

S7::method(schema_validate, SchemaDoc) <- function(schema, x, mode = "assert", name = NULL, ...) {
    schema_validate(schema_flat__compile(schema), x, mode = mode, name = name, ...)
}
# }}}
