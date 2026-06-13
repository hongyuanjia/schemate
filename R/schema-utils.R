# shared utilities {{{
schema_utils__coalesce <- function(x, y) {
    if (is.null(x)) y else x
}

schema_utils__checkmate_result <- function(result, label = NULL) {
    if (isTRUE(result)) {
        return(NULL)
    }

    substr(result, 1L, 1L) <- tolower(substr(result, 1L, 1L))

    if (!is.null(label)) {
        return(sprintf("%s: %s", label, result))
    }

    result
}

schema_utils__formal_args <- function(def) {
    names(formals(def, envir = parent.frame()))
}

schema_utils__require_namespace <- function(pkg, reason) {
    if (requireNamespace(pkg, quietly = TRUE)) {
        return(invisible(TRUE))
    }

    stop(
        sprintf(
            "Package `%s` is required to %s. Install it with `install.packages(\"%s\")`.",
            pkg,
            reason,
            pkg
        ),
        call. = FALSE
    )
}

schema_utils__checkmate_fun_cache <- new.env(parent = emptyenv())

schema_utils__checkmate_fun <- function(kind) {
    checkmate::assert_string(kind)
    fun <- schema_utils__checkmate_fun_cache[[kind]]
    if (is.null(fun)) {
        fun <- utils::getFromNamespace(paste0("check_", kind), asNamespace("checkmate"))
        schema_utils__checkmate_fun_cache[[kind]] <- fun
    }

    fun
}

schema_utils__checkmate_args <- function(kind) {
    schema_utils__formal_args(schema_utils__checkmate_fun(kind))[-1L]
}

schema_utils__checkmate_validator <- function(check, ..., label = NULL) {
    checkmate::assert_function(check)

    args <- list(...)
    force(label)

    function(value) {
        schema_utils__checkmate_result(do.call(check, c(list(value), args)), label = label)
    }
}

schema_utils__checkmate_rule <- function(class, check, ..., label = NULL, branch = NULL) {
    checkmate::assert_function(check)
    checkmate::assert_string(label, null.ok = TRUE)
    checkmate::assert_string(branch, null.ok = TRUE)

    if (!isS4(class)) {
        checkmate::assert_multi_class(
            class,
            c("S7_class", "S7_base_class", "S7_S3_class", "S7_missing", "S7_any"),
            null.ok = TRUE
        )
    }

    structure(
        list(
            class = class,
            check = check,
            args = list(...),
            label = label,
            branch = branch
        ),
        class = "CheckmateRule"
    )
}

schema_utils__checkmate_any <- function(...) {
    rules <- list(...)
    checkmate::assert_list(rules, "CheckmateRule", any.missing = FALSE, min.len = 1L, null.ok = FALSE)

    structure(
        list(
            mode = "any",
            rules = rules,
            class = Reduce(`|`, lapply(rules, `[[`, "class"))
        ),
        class = c("CheckmateSpecAny", "CheckmateSpec")
    )
}

schema_utils__base_type <- function(value) {
    switch(
        typeof(value),
        closure = ,
        builtin = ,
        special = "function",
        language = "call",
        symbol = "name",
        typeof(value)
    )
}

schema_utils__match_class <- function(value, class) {
    if (is.null(class)) {
        return(is.null(value))
    }
    if (inherits(class, "S7_any")) {
        return(TRUE)
    }
    if (inherits(class, "S7_missing")) {
        return(missing(value))
    }
    if (inherits(class, "S7_base_class")) {
        return(identical(schema_utils__base_type(value), class$class))
    }
    if (inherits(class, "S7_union")) {
        return(any(vapply(class$classes, schema_utils__match_class, logical(1L), value = value)))
    }
    if (inherits(class, "S7_S3_class")) {
        return(!isS4(value) && all(class$class %in% class(value)))
    }
    if (inherits(class, "S7_class")) {
        return(S7::S7_inherits(value, class))
    }
    if (isS4(class)) {
        return(isS4(value) && inherits(value, class@className))
    }

    inherits(value, class)
}

schema_utils__checkmate_match_rule <- function(value, rules) {
    for (i in seq_along(rules)) {
        rule_class <- rules[[i]]$class

        if (schema_utils__match_class(value, rule_class)) {
            return(i)
        }
    }

    NA_integer_
}

schema_utils__checkmate_validate_rule <- function(value, rule) {
    msg <- schema_utils__checkmate_result(
        do.call(rule$check, c(list(value), rule$args)),
        label = rule$label
    )

    if (!is.null(msg) && !is.null(rule$branch)) {
        msg <- sprintf("[%s] %s", rule$branch, msg)
    }

    msg
}

schema_utils__checkmate_property <- function(
    class = S7::class_any,
    check,
    ...,
    getter = NULL,
    setter = NULL,
    default = NULL,
    name = NULL,
    label = NULL
) {
    if (inherits(class, "CheckmateSpec")) {
        spec <- class
        extra_args <- list(...)

        if (!missing(check)) {
            stop("When `class` is a `CheckmateSpec`, `check` must be omitted.", call. = FALSE)
        }
        if (length(extra_args)) {
            stop(
                "When `class` is a `CheckmateSpec`, checker arguments must be supplied in `schema_utils__checkmate_rule()`.",
                call. = FALSE
            )
        }
        if (!is.null(label)) {
            stop(
                "When `class` is a `CheckmateSpec`, `label` must be supplied in `schema_utils__checkmate_rule()`.",
                call. = FALSE
            )
        }

        return(S7::new_property(
            class = spec$class,
            getter = getter,
            setter = setter,
            validator = function(value) {
                idx <- schema_utils__checkmate_match_rule(value, spec$rules)

                if (is.na(idx)) {
                    return("No matching validation branch found.")
                }

                schema_utils__checkmate_validate_rule(value, spec$rules[[idx]])
            },
            default = default,
            name = name
        ))
    }

    if (missing(check)) {
        stop("`check` must be supplied unless `class` is a `CheckmateSpec`.")
    }

    S7::new_property(
        class = class,
        getter = getter,
        setter = setter,
        validator = schema_utils__checkmate_validator(check, ..., label = label),
        default = default,
        name = name
    )
}

schema_utils__convert <- S7::new_generic(
    "schema_utils__convert",
    "from",
    function(from, to, ...) S7::S7_dispatch()
)
# }}}

# schema_utils__prop {{{
schema_utils__prop <- function(class, check, null.ok = FALSE, ...) {
    checkmate::assert_flag(null.ok)

    if (null.ok) {
        if (!"null.ok" %in% schema_utils__formal_args(check)) {
            stop("input checkmate function does not support `null.ok` argument, but `null.ok = TRUE` was specified.")
        }
        class <- NULL | class
    }

    schema_utils__checkmate_property(
        class,
        check,
        null.ok = null.ok,
        ...
    )
}

schema_utils__prop_string <- function(min.chars = 1L, null.ok = TRUE, default = NULL, ...) {
    schema_utils__prop(
        S7::class_character,
        checkmate::check_string,
        null.ok = null.ok,
        min.chars = min.chars,
        default = default,
        ...
    )
}

schema_utils__prop_character <- function(any.missing = FALSE, min.chars = 1L, null.ok = FALSE, default = NULL, ...) {
    schema_utils__prop(
        S7::class_character,
        checkmate::check_character,
        null.ok = null.ok,
        any.missing = any.missing,
        min.chars = min.chars,
        default = default,
        ...
    )
}

schema_utils__prop_choice <- function(choices, null.ok = TRUE, default = NULL, ...) {
    schema_utils__prop(
        S7::class_character,
        checkmate::check_choice,
        choices = choices,
        null.ok = null.ok,
        default = default,
        ...
    )
}

schema_utils__prop_list <- function(types = character(), names = "unique", null.ok = TRUE, default = list(), ...) {
    if (length(types) && !is.null(utils::packageName())) {
        types <- unique(c(paste0(utils::packageName(), "::", types), types))
    }

    schema_utils__prop(
        S7::class_list,
        checkmate::check_list,
        types = types,
        names = names,
        null.ok = null.ok,
        default = default,
        ...
    )
}

schema_utils__prop_ref <- function(null.ok = TRUE) {
    schema_utils__prop_string(
        null.ok = null.ok,
        min.chars = 1L,
        pattern = "^#/\\$defs/[^/]+$"
    )
}
# }}}

schema_utils__as_json <- S7::new_generic("schema_utils__as_json", "x", function(x, ...) S7::S7_dispatch())

schema_utils__as_list_add_desc <- function(out, x) {
    if (is.null(x@desc)) {
        return(out)
    }

    c(list(description = x@desc), out)
}

schema_utils__as_list_nary <- function(x, operator) {
    out <- list()
    out[[operator]] <- lapply(x@branches, as.list)
    schema_utils__as_list_add_desc(out, x)
}

schema_utils__as_list_rule <- function(x) {
    c(list(kind = x@kind), unclass(x@args))
}

schema_utils__as_list_rule_names <- function(x, drop_kind = FALSE, empty_as_null = FALSE) {
    if (is.null(x)) {
        return(NULL)
    }

    args <- unclass(x@args)
    if (drop_kind) {
        args <- args[names(args) != "kind"]
    }
    if (empty_as_null && !length(args)) {
        return(NULL)
    }

    args
}

schema_utils__keys_as_list <- function(x, empty_as_null = TRUE) {
    schema_utils__as_list_rule_names(x, drop_kind = TRUE, empty_as_null = empty_as_null)
}

schema_utils__json_indent <- function(depth, pretty) {
    if (!pretty) {
        return("")
    }

    paste(rep("  ", depth), collapse = "")
}

schema_utils__json_quote <- function(x) {
    out <- encodeString(x, quote = "\"", justify = "none")
    out[is.na(x)] <- "null"
    out
}

schema_utils__json_convert <- function(x, depth = 0L, pretty = TRUE, auto_unbox = TRUE) {
    if (is.list(x)) {
        return(schema_utils__json_convert_list(x, depth = depth, pretty = pretty, auto_unbox = auto_unbox))
    }

    schema_utils__json_convert_atom(x, depth = depth, pretty = pretty, auto_unbox = auto_unbox)
}

schema_utils__json_convert_list <- function(x, depth, pretty, auto_unbox) {
    nms <- names(x)
    named <- !is.null(nms)
    indent <- schema_utils__json_indent(depth, pretty = pretty)
    child_indent <- schema_utils__json_indent(depth + 1L, pretty = pretty)
    newline <- if (pretty) "\n" else ""
    space <- if (pretty) " " else ""

    if (!length(x)) {
        return(if (named) "{}" else "[]")
    }

    values <- vapply(
        x,
        schema_utils__json_convert,
        character(1L),
        depth = depth + 1L,
        pretty = pretty,
        auto_unbox = auto_unbox,
        USE.NAMES = FALSE
    )

    if (!named) {
        if (!pretty) {
            return(paste0("[", paste(values, collapse = ","), "]"))
        }

        return(paste0(
            "[",
            newline,
            child_indent,
            paste(values, collapse = paste0(",", newline, child_indent)),
            newline,
            indent,
            "]"
        ))
    }

    keys <- schema_utils__json_quote(nms)
    entries <- paste0(keys, ":", space, values)
    if (!pretty) {
        return(paste0("{", paste(entries, collapse = ","), "}"))
    }

    paste0(
        "{",
        newline,
        child_indent,
        paste(entries, collapse = paste0(",", newline, child_indent)),
        newline,
        indent,
        "}"
    )
}

schema_utils__json_convert_atom <- function(x, depth, pretty, auto_unbox) {
    if (is.null(x)) {
        return("null")
    }

    if (!length(x)) {
        return("[]")
    }

    if (is.character(x)) {
        values <- schema_utils__json_quote(x)
    } else if (is.logical(x)) {
        values <- ifelse(x, "true", "false")
        values[is.na(x)] <- "null"
    } else if (is.numeric(x)) {
        values <- as.character(x)
        values[is.na(x) | !is.finite(x)] <- "null"
    } else {
        stop(sprintf("Cannot serialize object of type `%s` with base R JSON fallback.", typeof(x)), call. = FALSE)
    }

    if (auto_unbox && length(values) == 1L) {
        return(values[[1L]])
    }

    indent <- schema_utils__json_indent(depth, pretty = pretty)
    child_indent <- schema_utils__json_indent(depth + 1L, pretty = pretty)
    newline <- if (pretty) "\n" else ""

    if (!pretty) {
        return(paste0("[", paste(values, collapse = ","), "]"))
    }

    paste0(
        "[",
        newline,
        child_indent,
        paste(values, collapse = paste0(",", newline, child_indent)),
        newline,
        indent,
        "]"
    )
}

schema_utils__to_json_fallback <- function(x, pretty = TRUE, auto_unbox = TRUE) {
    if (is.object(x) && !is.list(x)) {
        x <- as.list(x)
    }

    schema_utils__json_convert(x, depth = 0L, pretty = pretty, auto_unbox = auto_unbox)
}

schema_utils__as_json_impl <- function(x, pretty = TRUE, auto_unbox = TRUE) {
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
        return(schema_utils__to_json_fallback(x, pretty = pretty, auto_unbox = auto_unbox))
    }

    jsonlite::toJSON(
        as.list(x),
        pretty = pretty,
        auto_unbox = auto_unbox,
        null = "null",
        na = "null"
    )
}

schema_utils__cat_json <- function(x, ..., pretty = TRUE, auto_unbox = TRUE) {
    cat(schema_utils__as_json(x, pretty = pretty, auto_unbox = auto_unbox), "\n", sep = "")
    invisible(x)
}

# vim: fdm=marker :
