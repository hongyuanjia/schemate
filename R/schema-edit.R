#' @include schema-doc.R

SCHEMA_EDIT_RESERVED_TOKENS <- c(
    "fields",
    "defs",
    "all",
    "any",
    "one",
    "not",
    "groups",
    "patterns",
    "positions",
    "rest",
    "check",
    "keys",
    "description",
    "version"
)

schema_edit__is_reserved_token <- function(token) {
    checkmate::test_choice(token, SCHEMA_EDIT_RESERVED_TOKENS)
}

schema_edit__parse_quoted_segment <- function(path, pos) {
    n <- nchar(path)
    chars <- character()
    pos <- pos + 1L

    while (pos <= n) {
        chr <- substring(path, pos, pos)

        if (identical(chr, "`")) {
            segment <- paste0(chars, collapse = "")
            if (!nzchar(segment)) {
                stop(sprintf("`path` contains an empty quoted segment near `%s`.", substring(path, pos)), call. = FALSE)
            }
            return(list(segment = segment, pos = pos + 1L))
        }

        if (identical(chr, "\\")) {
            if (pos == n) {
                stop(sprintf("Unsupported path escape near `%s`.", substring(path, pos)), call. = FALSE)
            }
            next_chr <- substring(path, pos + 1L, pos + 1L)
            if (!next_chr %in% c("`", "\\")) {
                stop(sprintf("Unsupported path escape near `%s`.", substring(path, pos)), call. = FALSE)
            }
            chars[[length(chars) + 1L]] <- next_chr
            pos <- pos + 2L
            next
        }

        chars[[length(chars) + 1L]] <- chr
        pos <- pos + 1L
    }

    stop(sprintf("Unterminated quoted path segment near `%s`.", substring(path, pos)), call. = FALSE)
}

schema_edit__parse_path <- function(path) {
    checkmate::assert_string(path, min.chars = 1L)
    if (!startsWith(path, "$")) {
        stop("`path` must start with `$`.", call. = FALSE)
    }
    if (identical(path, "$")) {
        return(list())
    }

    tokens <- list()
    pos <- 2L
    n <- nchar(path)

    while (pos <= n) {
        chr <- substring(path, pos, pos)

        if (identical(chr, "$")) {
            if (pos == 2L || pos == n || substring(path, pos + 1L, pos + 1L) %in% c("$", "[")) {
                stop(sprintf("`path` contains an empty segment near `%s`.", substring(path, pos)), call. = FALSE)
            }
            pos <- pos + 1L
            next
        }

        if (identical(chr, "`")) {
            quoted <- schema_edit__parse_quoted_segment(path, pos)
            tokens[[length(tokens) + 1L]] <- quoted$segment
            pos <- quoted$pos
            if (pos <= n && !(substring(path, pos, pos) %in% c("$", "["))) {
                stop(sprintf("Unsupported path segment near `%s`.", substring(path, pos)), call. = FALSE)
            }
            next
        }

        if (identical(chr, "[")) {
            if (!length(tokens)) {
                stop(sprintf("Unsupported path index near `%s`.", substring(path, pos)), call. = FALSE)
            }
            index_text <- substring(path, pos)
            match <- regexec("^\\[([0-9]+)\\]", index_text)
            hit <- regmatches(index_text, match)[[1L]]
            if (!length(hit)) {
                stop(sprintf("Unsupported path index near `%s`.", substring(path, pos)), call. = FALSE)
            }
            tokens[[length(tokens) + 1L]] <- as.integer(hit[[2L]])
            pos <- pos + nchar(hit[[1L]])
            next
        }

        start <- pos
        while (pos <= n && !(substring(path, pos, pos) %in% c("$", "["))) {
            pos <- pos + 1L
        }
        segment <- substring(path, start, pos - 1L)
        if (!nzchar(segment)) {
            stop(sprintf("Unsupported path segment near `%s`.", substring(path, start)), call. = FALSE)
        }
        tokens[[length(tokens) + 1L]] <- segment
    }

    tokens
}

schema_edit__ref_value <- function(x) {
    checkmate::assert_string(x, min.chars = 1L)

    if (grepl("^#/\\$defs/[^/]+$", x)) {
        return(x)
    }

    if (grepl("/", x, fixed = TRUE)) {
        stop("`name` must be a definition name or a local ref of the form `#/$defs/name`.", call. = FALSE)
    }

    paste0("#/$defs/", x)
}

schema_edit__abort_with_context <- function(context, error) {
    message <- conditionMessage(error)
    if (startsWith(message, context)) {
        stop(message, call. = FALSE)
    }
    stop(sprintf("%s\n%s", context, message), call. = FALSE)
}

schema_edit__as_node <- function(x, defs, path, context = sprintf("Invalid schema fragment at path `%s`.", path)) {
    tryCatch(
        {
            if (S7::S7_inherits(x, SchemaNode)) {
                return(x)
            }
            schema_spec__node(x, path = path, defs = defs, root = FALSE)
        },
        error = function(e) {
            schema_edit__abort_with_context(context, e)
        }
    )
}

schema_edit__as_group_binding <- function(
    x,
    defs,
    path,
    context = sprintf("Invalid schema group at path `%s`.", path)
) {
    tryCatch(
        schema_spec__binding_groups(list(x), path = path, defs = defs)[[1L]],
        error = function(e) {
            schema_edit__abort_with_context(context, e)
        }
    )
}

schema_edit__field_binding_index <- function(bindings, name) {
    idx <- which(vapply(
        bindings,
        function(binding) name %in% binding@keys,
        logical(1L)
    ))

    if (!length(idx)) {
        return(NA_integer_)
    }

    idx[[1L]]
}

schema_edit__exact_slice <- function(bindings, from, to) {
    if (from > to) {
        return(list())
    }

    bindings[from:to]
}

schema_edit__exact_binding <- function(keys, target) {
    if (!length(keys)) {
        return(NULL)
    }

    list(SchemaBindingExactCmpt(keys = keys, target = target))
}

schema_edit__replace_field_binding <- function(bindings, index, name, target) {
    binding <- bindings[[index]]
    pos <- match(name, binding@keys)
    if (is.na(pos)) {
        stop(sprintf("Field `%s` does not exist.", name), call. = FALSE)
    }

    remaining <- binding@keys[-pos]
    shared <- schema_edit__exact_binding(remaining, binding@target)
    field <- schema_edit__exact_binding(name, target)

    c(
        schema_edit__exact_slice(bindings, 1L, index - 1L),
        shared,
        field,
        schema_edit__exact_slice(bindings, index + 1L, length(bindings))
    )
}

schema_edit__delete_field_binding <- function(bindings, index, name) {
    binding <- bindings[[index]]
    pos <- match(name, binding@keys)
    if (is.na(pos)) {
        stop(sprintf("Field `%s` does not exist.", name), call. = FALSE)
    }

    remaining <- binding@keys[-pos]
    replacement <- schema_edit__exact_binding(remaining, binding@target)
    c(
        schema_edit__exact_slice(bindings, 1L, index - 1L),
        replacement,
        schema_edit__exact_slice(bindings, index + 1L, length(bindings))
    )
}

schema_edit__node_refs <- function(node) {
    if (S7::S7_inherits(node, SchemaNodeRef)) {
        return(node@ref)
    }
    if (S7::S7_inherits(node, SchemaNodeContainerCmpt)) {
        refs <- unlist(
            lapply(node@exact, function(binding) schema_edit__node_refs(binding@target)),
            use.names = FALSE
        )
        refs <- c(
            refs,
            unlist(lapply(node@patterns, function(binding) schema_edit__node_refs(binding@target)), use.names = FALSE)
        )
        refs <- c(refs, unlist(lapply(node@positions, schema_edit__node_refs), use.names = FALSE))
        if (!is.null(node@rest)) {
            refs <- c(refs, schema_edit__node_refs(node@rest))
        }
        return(refs)
    }
    if (S7::S7_inherits(node, SchemaNodeNaryCmpt)) {
        return(unlist(lapply(node@branches, schema_edit__node_refs), use.names = FALSE))
    }
    if (S7::S7_inherits(node, SchemaNodeNotCmpt)) {
        return(schema_edit__node_refs(node@branch))
    }

    character()
}

schema_edit__update_node <- function(node, ...) {
    S7::set_props(node, ...)
}

schema_edit__path_not_found <- function(path) {
    stop(sprintf("`path` does not exist: %s", path), call. = FALSE)
}

schema_edit__modify_container_child <- function(node, kind, key, tokens, fn, path) {
    checkmate::assert_choice(kind, c("field", "group"))

    if (identical(kind, "field")) {
        if (!is.character(key)) {
            schema_edit__path_not_found(path)
        }

        index <- schema_edit__field_binding_index(node@exact, key)
        if (is.na(index)) {
            schema_edit__path_not_found(path)
        }
    } else {
        if (!is.numeric(key)) {
            schema_edit__path_not_found(path)
        }

        group_index <- which(vapply(node@exact, function(binding) length(binding@keys) > 1L, logical(1L)))
        if (key < 1L || key > length(group_index)) {
            schema_edit__path_not_found(path)
        }
        index <- group_index[[key]]
    }

    exact <- node@exact
    target <- schema_edit__modify_tree(exact[[index]]@target, tokens, fn, path)
    exact <- if (identical(kind, "field")) {
        schema_edit__replace_field_binding(exact, index, key, target)
    } else {
        exact[[index]] <- SchemaBindingExactCmpt(
            keys = exact[[index]]@keys,
            target = target
        )
        exact
    }
    schema_edit__update_node(node, exact = exact)
}

schema_edit__modify_tree <- S7::new_generic(
    "schema_edit__modify_tree",
    "node",
    function(node, tokens, fn, path) {
        if (!length(tokens)) {
            return(fn(node))
        }
        S7::S7_dispatch()
    }
)

S7::method(schema_edit__modify_tree, SchemaNode) <- function(node, tokens, fn, path) {
    schema_edit__path_not_found(path)
}

S7::method(schema_edit__modify_tree, SchemaNodeContainerCmpt) <- function(node, tokens, fn, path) {
    token <- tokens[[1L]]
    rest <- tokens[-1L]

    if (is.character(token) && token %in% c("fields", "groups")) {
        kind <- if (identical(token, "fields")) "field" else "group"
        if (!length(rest) || (identical(kind, "field") && !is.character(rest[[1L]]))) {
            schema_edit__path_not_found(path)
        }
        return(schema_edit__modify_container_child(node, kind, rest[[1L]], rest[-1L], fn, path))
    }

    if (is.character(token) && identical(token, "rest")) {
        if (is.null(node@rest)) {
            schema_edit__path_not_found(path)
        }
        return(schema_edit__update_node(
            node,
            rest = schema_edit__modify_tree(node@rest, rest, fn, path)
        ))
    }

    if (is.character(token) && identical(token, "positions")) {
        if (!length(rest) || !is.numeric(rest[[1L]])) {
            schema_edit__path_not_found(path)
        }
        index <- rest[[1L]]
        if (index < 1L || index > length(node@positions)) {
            schema_edit__path_not_found(path)
        }

        positions <- node@positions
        positions[[index]] <- schema_edit__modify_tree(positions[[index]], rest[-1L], fn, path)
        return(schema_edit__update_node(node, positions = positions))
    }

    if (is.character(token) && !schema_edit__is_reserved_token(token)) {
        return(schema_edit__modify_container_child(node, "field", token, rest, fn, path))
    }

    schema_edit__path_not_found(path)
}

S7::method(schema_edit__modify_tree, SchemaNodeNaryCmpt) <- function(node, tokens, fn, path) {
    token <- tokens[[1L]]
    rest <- tokens[-1L]
    operator <- if (S7::S7_inherits(node, SchemaNodeAllCmpt)) {
        "all"
    } else if (S7::S7_inherits(node, SchemaNodeAnyCmpt)) {
        "any"
    } else if (S7::S7_inherits(node, SchemaNodeOneCmpt)) {
        "one"
    } else {
        stop("Unsupported n-ary schema node type.", call. = FALSE)
    }

    if (!is.character(token) || !identical(token, operator) || !length(rest) || !is.numeric(rest[[1L]])) {
        schema_edit__path_not_found(path)
    }

    index <- rest[[1L]]
    if (index < 1L || index > length(node@branches)) {
        schema_edit__path_not_found(path)
    }

    branches <- node@branches
    branches[[index]] <- schema_edit__modify_tree(branches[[index]], rest[-1L], fn, path)
    schema_edit__update_node(node, branches = branches)
}

S7::method(schema_edit__modify_tree, SchemaNodeNotCmpt) <- function(node, tokens, fn, path) {
    token <- tokens[[1L]]
    if (!is.character(token) || !identical(token, "not")) {
        schema_edit__path_not_found(path)
    }

    schema_edit__update_node(
        node,
        branch = schema_edit__modify_tree(node@branch, tokens[-1L], fn, path)
    )
}

schema_edit__modify_doc <- function(x, path, fn) {
    doc <- x
    tokens <- schema_edit__parse_path(path)

    if (!length(tokens)) {
        return(schema_edit__update_node(doc, root = fn(doc@root)))
    }

    if (is.character(tokens[[1L]]) && identical(tokens[[1L]], "defs")) {
        if (length(tokens) < 2L || !is.character(tokens[[2L]])) {
            stop(sprintf("`path` does not exist: %s", path), call. = FALSE)
        }
        name <- tokens[[2L]]
        if (is.null(doc@defs[[name]])) {
            stop(sprintf("`path` does not exist: %s", path), call. = FALSE)
        }

        defs_list <- doc@defs
        defs_list[[name]] <- schema_edit__modify_tree(defs_list[[name]], tokens[-c(1L, 2L)], fn, path)
        return(schema_edit__update_node(doc, defs = defs_list))
    }

    schema_edit__update_node(doc, root = schema_edit__modify_tree(doc@root, tokens, fn, path))
}

schema_edit__normalize_fragment <- function(x, what) {
    if (S7::S7_inherits(x, SchemaNode)) {
        return(as.list(x))
    }

    if (is.list(x)) {
        return(x)
    }

    stop(sprintf("Expected %s or `SchemaNode` object.", what), call. = FALSE)
}

schema_edit__combinator <- function(operator, branches, description = NULL) {
    checkmate::assert_choice(operator, c("all", "any", "one"))
    checkmate::assert_string(description, null.ok = TRUE)
    if (!length(branches)) {
        stop(sprintf("`schema_%s()` requires at least one branch.", operator), call. = FALSE)
    }
    if (!is.null(names(branches)) && any(nzchar(names(branches)))) {
        stop(sprintf("`schema_%s()` branches must be unnamed.", operator), call. = FALSE)
    }

    out <- list()
    out[[operator]] <- lapply(
        branches,
        schema_edit__normalize_fragment,
        what = "a schema branch fragment"
    )
    if (!is.null(description)) {
        out <- c(list(description = description), out)
    }
    out
}

schema_edit__group_value <- function(value, description = NULL) {
    value <- schema_edit__normalize_fragment(value, "a schema node fragment")
    operators <- names(value)[names(value) %in% SCHEMA_SPEC_OPERATORS]
    if (length(operators) != 1L) {
        stop("`value` must contain exactly one primary schema operator.", call. = FALSE)
    }

    desc <- schema_utils__coalesce(description, value$description)
    value <- value[names(value) != "description"]
    if (!is.null(desc)) {
        value <- c(list(description = desc), value)
    }
    value
}

#' Create a schema check fragment
#'
#' `schema_check()` creates a raw schema fragment with a `check` operator. The
#' helper performs only lightweight structural validation; semantic validation of
#' `kind` and check arguments is handled by `schema_doc()` and schema edit verbs.
#'
#' @param kind Check kind string.
#' @param ... Additional named checkmate arguments stored inside `check`.
#' @param description Optional node description.
#'
#' @return A raw schema fragment accepted by `schema_doc()` and schema edit verbs.
#'
#' @examples
#' schema_check("string", min.chars = 1)
#' schema <- schema_doc(schema_check("string", min.chars = 1))
#' schema
#'
#' @export
schema_check <- function(kind, ..., description = NULL) {
    checkmate::assert_string(kind, min.chars = 1L)
    checkmate::assert_string(description, null.ok = TRUE)
    dots <- list(...)
    if (length(dots)) {
        dot_names <- names(dots)
        if (is.null(dot_names) || !all(nzchar(dot_names))) {
            stop("`kind` must be supplied once; `...` must be named and must not include `kind`.", call. = FALSE)
        }
        if ("kind" %in% dot_names) {
            stop("`...` must not include `kind`.", call. = FALSE)
        }
        checkmate::assert_names(dot_names, type = "named")
        if (anyDuplicated(dot_names)) {
            stop("`...` must use unique names.", call. = FALSE)
        }
    }

    out <- list(check = c(list(kind = kind), dots))
    if (!is.null(description)) {
        out <- c(list(description = description), out)
    }
    out
}

#' Create a schema reference fragment
#'
#' `schema_ref()` creates a local `$defs` reference fragment. `name` may be
#' either a bare definition name such as `"text"` or a local ref string of the
#' form `"#/$defs/text"`.
#'
#' @param name Definition name or local `$defs` ref string.
#' @param description Optional node description.
#'
#' @return A raw schema fragment accepted by `schema_doc()` and schema edit verbs.
#'
#' @examples
#' schema <- schema_doc(list(
#'     `$defs` = list(text = schema_check("string")),
#'     `$ref` = "#/$defs/text"
#' ))
#' schema
#'
#' schema_validate(schema, "ok", mode = "test")
#' schema_ref("text")
#'
#' @export
schema_ref <- function(name, description = NULL) {
    checkmate::assert_string(description, null.ok = TRUE)

    out <- list(`$ref` = schema_edit__ref_value(name))
    if (!is.null(description)) {
        out <- c(list(description = description), out)
    }
    out
}

#' Create an `all` schema combinator fragment
#'
#' @param ... Branch schema fragments.
#' @param description Optional node description.
#'
#' @return A raw schema fragment accepted by `schema_doc()` and schema edit verbs.
#'
#' @examples
#' schema <- schema_doc(schema_all(
#'     schema_check("string"),
#'     schema_check("string", min.chars = 1)
#' ))
#' schema
#'
#' schema_validate(schema, "ok", mode = "test")
#'
#' @export
schema_all <- function(..., description = NULL) {
    schema_edit__combinator("all", list(...), description = description)
}

#' Create an `any` schema combinator fragment
#'
#' @param ... Branch schema fragments.
#' @param description Optional node description.
#'
#' @return A raw schema fragment accepted by `schema_doc()` and schema edit verbs.
#'
#' @examples
#' schema <- schema_doc(schema_any(schema_check("int"), schema_check("string")))
#' schema
#'
#' schema_validate(schema, "ok", mode = "test")
#'
#' @export
schema_any <- function(..., description = NULL) {
    schema_edit__combinator("any", list(...), description = description)
}

#' Create a `one` schema combinator fragment
#'
#' @param ... Branch schema fragments.
#' @param description Optional node description.
#'
#' @return A raw schema fragment accepted by `schema_doc()` and schema edit verbs.
#'
#' @examples
#' schema <- schema_doc(schema_one(schema_check("int"), schema_check("string")))
#' schema
#'
#' schema_validate(schema, "ok", mode = "test")
#'
#' @export
schema_one <- function(..., description = NULL) {
    schema_edit__combinator("one", list(...), description = description)
}

#' Create a `not` schema combinator fragment
#'
#' @param branch Branch schema fragment.
#' @param description Optional node description.
#'
#' @return A raw schema fragment accepted by `schema_doc()` and schema edit verbs.
#'
#' @examples
#' schema <- schema_doc(schema_not(schema_check("null")))
#' schema
#'
#' schema_validate(schema, "ok", mode = "test")
#'
#' @export
schema_not <- function(branch, description = NULL) {
    checkmate::assert_string(description, null.ok = TRUE)

    out <- list(not = schema_edit__normalize_fragment(branch, "a schema branch fragment"))
    if (!is.null(description)) {
        out <- c(list(description = description), out)
    }
    out
}

#' Create a schema group fragment
#'
#' @param names Field names covered by the group.
#' @param value Schema node fragment containing exactly one primary operator.
#' @param description Optional group description.
#'
#' @return A raw schema group fragment accepted in a schema document `groups`
#'   list or by `schema_add_group()`.
#'
#' @examples
#' schema <- schema_doc(list(
#'     check = list(kind = "list"),
#'     groups = list(schema_group(c("x", "y"), schema_check("number")))
#' ))
#' schema
#'
#' schema_validate(schema, list(x = 1, y = 2), mode = "test")
#'
#' @export
schema_group <- function(names, value, description = NULL) {
    checkmate::assert_character(names, any.missing = FALSE, min.len = 1L, unique = TRUE)

    c(list(names = names), schema_edit__group_value(value, description = description))
}

#' Replace a schema node
#'
#' @param x A `SchemaDoc`.
#' @param path Path to the target schema node. Use `$` for the root node. Bare
#'   field segments such as `$id` implicitly traverse container `fields`. Use
#'   `$fields$id` to write the explicit field path. Backtick-quote field names
#'   that contain path operators, for example ``$`a$b` ``.
#' @param value Replacement schema fragment using the same list syntax accepted
#'   by `schema_doc()`, or a fragment produced by helpers such as
#'   `schema_check()` or `schema_ref()`.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(list(
#'     check = list(kind = "list"),
#'     fields = list(id = schema_check("int"))
#' ))
#' schema <- schema_replace(schema, "$id", schema_check("int", lower = 1))
#' schema
#'
#' schema_validate(schema, list(id = 1L), mode = "test")
#'
#' @export
schema_replace <- S7::new_generic(
    "schema_replace",
    "x",
    function(x, path = "$", value) {
        S7::S7_dispatch()
    }
)

S7::method(schema_replace, SchemaDoc) <- function(x, path = "$", value) {
    schema_edit__modify_doc(x, path, function(node) {
        schema_edit__as_node(
            value,
            defs = names(x@defs),
            path = path,
            context = sprintf("Invalid replacement at path `%s`.", path)
        )
    })
}

#' Set or remove a schema node description
#'
#' @param x A `SchemaDoc`.
#' @param path Path to the target schema node. Use `$` for the root node. Bare
#'   field segments such as `$id` implicitly traverse container `fields`. Use
#'   `$fields$id` to write the explicit field path. Backtick-quote field names
#'   that contain path operators, for example ``$`a$b` ``.
#' @param description Optional description string. Use `NULL` to remove the
#'   description.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(schema_check("string"))
#' schema_set_desc(schema, "$", "A non-empty label.")
#'
#' @export
schema_set_desc <- S7::new_generic(
    "schema_set_desc",
    "x",
    function(x, path = "$", description = NULL) {
        S7::S7_dispatch()
    }
)

S7::method(schema_set_desc, SchemaDoc) <- function(x, path = "$", description = NULL) {
    checkmate::assert_string(description, null.ok = TRUE)

    schema_edit__modify_doc(x, path, function(node) {
        schema_edit__update_node(node, desc = description)
    })
}

#' Set a schema node keys rule
#'
#' @param x A `SchemaDoc`.
#' @param path Path to the target schema node. Use `$` for the root node. Bare
#'   field segments such as `$id` implicitly traverse container `fields`. Use
#'   `$fields$id` to write the explicit field path. Backtick-quote field names
#'   that contain path operators, for example ``$`a$b` ``.
#' @param ... Named `keys` rule arguments passed through to the schema DSL.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(list(check = list(kind = "list")))
#' schema
#' schema_validate(schema, list(id = 1L), mode = "test")
#'
#' schema <- schema_set_keys(schema, type = "named", must.include = "id")
#' schema
#' schema_validate(schema, list(id = 1L), mode = "assert")
#'
#' @export
schema_set_keys <- S7::new_generic(
    "schema_set_keys",
    "x",
    function(x, path = "$", ...) {
        S7::S7_dispatch()
    }
)

S7::method(schema_set_keys, SchemaDoc) <- function(x, path = "$", ...) {
    dots <- list(...)

    if (!length(dots)) {
        stop("Supply at least one keys-rule argument.", call. = FALSE)
    }

    schema_edit__modify_doc(x, path, function(node) {
        if (!S7::S7_inherits(node, SchemaNodeCheck)) {
            stop("`keys` is only allowed on check nodes.", call. = FALSE)
        }
        rule <- schema_spec__name_rule(dots, paste0(path, "$keys"))
        schema_edit__update_node(node, name = rule)
    })
}

#' Delete a schema node keys rule
#'
#' @param x A `SchemaDoc`.
#' @param path Path to the target schema node. Use `$` for the root node. Bare
#'   field segments such as `$id` implicitly traverse container `fields`. Use
#'   `$fields$id` to write the explicit field path. Backtick-quote field names
#'   that contain path operators, for example ``$`a$b` ``.
#' @param error_if_missing Logical flag indicating whether a missing `keys` rule
#'   should raise an error.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(list(check = list(kind = "list"), keys = list(type = "named")))
#' schema <- schema_del_keys(schema)
#' schema
#'
#' as.list(schema)$keys
#'
#' @export
schema_del_keys <- S7::new_generic(
    "schema_del_keys",
    "x",
    function(x, path = "$", error_if_missing = TRUE) {
        S7::S7_dispatch()
    }
)

S7::method(schema_del_keys, SchemaDoc) <- function(x, path = "$", error_if_missing = TRUE) {
    checkmate::assert_flag(error_if_missing)

    schema_edit__modify_doc(x, path, function(node) {
        if (!S7::S7_inherits(node, SchemaNodeCheck)) {
            stop("`keys` is only allowed on check nodes.", call. = FALSE)
        }
        if (is.null(node@name)) {
            if (error_if_missing) {
                stop(sprintf("`keys` does not exist at `%s`.", path), call. = FALSE)
            }
            return(node)
        }
        schema_edit__update_node(node, name = NULL)
    })
}

#' Add a field schema to a container node
#'
#' @param x A `SchemaDoc`.
#' @param name Field name to add.
#' @param field Schema fragment using the same list syntax accepted by
#'   `schema_doc()`, or a fragment produced by helpers such as `schema_check()`.
#' @param path Path to the target container node. Use `$` for the root node.
#'   Bare field segments such as `$id` implicitly traverse container `fields`. Use
#'   `$fields$id` to write the explicit field path. Backtick-quote field names
#'   that contain path operators, for example ``$`a$b` ``.
#' @param overwrite Logical flag indicating whether an existing field of the same
#'   name should be replaced.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(list(check = list(kind = "list")))
#' schema
#' schema <- schema_add_field(schema, "id", schema_check("int", lower = 1))
#' schema
#'
#' schema_validate(schema, list(id = 1L), mode = "test")
#'
#' @export
schema_add_field <- S7::new_generic(
    "schema_add_field",
    "x",
    function(x, name, field, path = "$", overwrite = FALSE) {
        S7::S7_dispatch()
    }
)

S7::method(schema_add_field, SchemaDoc) <- function(x, name, field, path = "$", overwrite = FALSE) {
    checkmate::assert_string(name, min.chars = 1L)
    checkmate::assert_flag(overwrite)
    doc <- x

    schema_edit__modify_doc(doc, path, function(node) {
        if (!S7::S7_inherits(node, SchemaNodeContainerCmpt)) {
            stop(sprintf("`path` does not identify a container node: %s", path), call. = FALSE)
        }

        idx <- schema_edit__field_binding_index(node@exact, name)
        if (!overwrite && !is.na(idx)) {
            stop(sprintf("Field `%s` already exists at `%s`.", name, path), call. = FALSE)
        }

        field <- schema_edit__as_node(
            field,
            defs = names(doc@defs),
            path = paste0(path, "$fields$", name),
            context = sprintf("Invalid field schema `%s` at path `%s`.", name, path)
        )

        binding <- SchemaBindingExactCmpt(keys = name, target = field)
        exact <- node@exact
        if (is.na(idx)) {
            exact[[length(exact) + 1L]] <- binding
        } else {
            exact <- schema_edit__replace_field_binding(exact, idx, name, field)
        }
        schema_edit__update_node(node, exact = exact)
    })
}

#' Add a schema group to a container node
#'
#' @param x A `SchemaDoc`.
#' @param group Schema group fragment using the same list syntax accepted by
#'   `schema_doc()`, or a fragment produced by `schema_group()`.
#' @param path Path to the target container node. Use `$` for the root node.
#'   Bare field segments such as `$id` implicitly traverse container `fields`. Use
#'   `$fields$id` to write the explicit field path. Backtick-quote field names
#'   that contain path operators, for example ``$`a$b` ``.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(list(check = list(kind = "list")))
#' schema
#' schema <- schema_add_group(schema, schema_group(c("x", "y"), schema_check("number")))
#' schema
#'
#' schema_validate(schema, list(x = 1, y = 2), mode = "test")
#'
#' @export
schema_add_group <- S7::new_generic(
    "schema_add_group",
    "x",
    function(x, group, path = "$") {
        S7::S7_dispatch()
    }
)

S7::method(schema_add_group, SchemaDoc) <- function(x, group, path = "$") {
    doc <- x

    schema_edit__modify_doc(doc, path, function(node) {
        if (!S7::S7_inherits(node, SchemaNodeContainerCmpt)) {
            stop(sprintf("`path` does not identify a container node: %s", path), call. = FALSE)
        }
        group <- schema_edit__as_group_binding(
            group,
            defs = names(doc@defs),
            path = paste0(path, "$groups"),
            context = sprintf("Invalid group schema at path `%s`.", path)
        )
        schema_edit__update_node(node, exact = c(node@exact, list(group)))
    })
}

#' Set or replace a container rest schema
#'
#' @param x A `SchemaDoc`.
#' @param field Schema fragment using the same list syntax accepted by
#'   `schema_doc()`, or a fragment produced by helpers such as `schema_check()`,
#'   to store as the `rest` schema.
#' @param path Path to the target container node. Use `$` for the root node.
#'   Bare field segments such as `$id` implicitly traverse container `fields`. Use
#'   `$fields$id` to write the explicit field path. Backtick-quote field names
#'   that contain path operators, for example ``$`a$b` ``.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(list(
#'     check = list(kind = "list"),
#'     keys = list(type = "unnamed")
#' ))
#' schema <- schema_set_rest(schema, schema_check("string"))
#' schema
#'
#' schema_validate(schema, list("a", "b"), mode = "test")
#'
#' @export
schema_set_rest <- S7::new_generic(
    "schema_set_rest",
    "x",
    function(x, field, path = "$") {
        S7::S7_dispatch()
    }
)

S7::method(schema_set_rest, SchemaDoc) <- function(x, field, path = "$") {
    doc <- x

    schema_edit__modify_doc(doc, path, function(node) {
        if (!S7::S7_inherits(node, SchemaNodeContainerCmpt)) {
            stop(sprintf("`path` does not identify a container node: %s", path), call. = FALSE)
        }
        field <- schema_edit__as_node(
            field,
            defs = names(doc@defs),
            path = paste0(path, "$rest"),
            context = sprintf("Invalid rest schema at path `%s`.", path)
        )
        schema_edit__update_node(node, rest = field)
    })
}

#' Add a position schema to an unnamed container node
#'
#' @param x A `SchemaDoc`.
#' @param index 1-based insertion index. `1` inserts at the front and
#'   `length(positions) + 1` appends.
#' @param value Schema fragment using the same list syntax accepted by
#'   `schema_doc()`, or a fragment produced by helpers such as `schema_check()`.
#' @param path Path to the target unnamed container node. Use `$` for the root
#'   node.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(list(
#'     check = list(kind = "list"),
#'     keys = list(type = "unnamed")
#' ))
#' schema <- schema_add_position(schema, 1, schema_check("string"))
#' schema <- schema_add_position(schema, 2, schema_check("int"))
#' schema
#'
#' schema_validate(schema, list("a", 1L), mode = "test")
#'
#' @export
schema_add_position <- S7::new_generic(
    "schema_add_position",
    "x",
    function(x, index, value, path = "$") {
        S7::S7_dispatch()
    }
)

S7::method(schema_add_position, SchemaDoc) <- function(x, index, value, path = "$") {
    checkmate::assert_count(index, positive = TRUE)
    doc <- x

    schema_edit__modify_doc(doc, path, function(node) {
        if (!S7::S7_inherits(node, SchemaNodeContainerCmpt)) {
            stop(sprintf("`path` does not identify a container node: %s", path), call. = FALSE)
        }
        if (!identical(schema_spec__name_type(node@name), "unnamed")) {
            stop("`positions` requires `keys$type = 'unnamed'`.", call. = FALSE)
        }
        if (index > length(node@positions) + 1L) {
            stop(sprintf("`index` must be at most %d at `%s`.", length(node@positions) + 1L, path), call. = FALSE)
        }

        value <- schema_edit__as_node(
            value,
            defs = names(doc@defs),
            path = sprintf("%s$positions[%d]", path, index),
            context = sprintf("Invalid position schema %d at path `%s`.", index, path)
        )

        positions <- append(node@positions, list(value), after = index - 1L)
        schema_edit__update_node(node, positions = positions)
    })
}

#' Delete a field schema from a container node
#'
#' @param x A `SchemaDoc`.
#' @param name Field name to remove.
#' @param path Path to the target container node. Use `$` for the root node.
#'   Bare field segments such as `$id` implicitly traverse container `fields`. Use
#'   `$fields$id` to write the explicit field path. Backtick-quote field names
#'   that contain path operators, for example ``$`a$b` ``.
#' @param error_if_missing Logical flag indicating whether a missing field should
#'   raise an error.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(list(check = list(kind = "list")))
#' schema
#' schema <- schema_add_field(schema, "id", schema_check("int"))
#' schema
#' schema <- schema_del_field(schema, "id")
#' schema
#'
#' @export
schema_del_field <- S7::new_generic(
    "schema_del_field",
    "x",
    function(x, name, path = "$", error_if_missing = TRUE) {
        S7::S7_dispatch()
    }
)

S7::method(schema_del_field, SchemaDoc) <- function(x, name, path = "$", error_if_missing = TRUE) {
    checkmate::assert_string(name, min.chars = 1L)
    checkmate::assert_flag(error_if_missing)

    schema_edit__modify_doc(x, path, function(node) {
        if (!S7::S7_inherits(node, SchemaNodeContainerCmpt)) {
            if (error_if_missing) {
                stop(sprintf("Field `%s` does not exist at `%s`.", name, path), call. = FALSE)
            }
            return(node)
        }

        idx <- schema_edit__field_binding_index(node@exact, name)
        if (is.na(idx)) {
            if (error_if_missing) {
                stop(sprintf("Field `%s` does not exist at `%s`.", name, path), call. = FALSE)
            }
            return(node)
        }

        exact <- node@exact
        exact <- schema_edit__delete_field_binding(exact, idx, name)
        schema_edit__update_node(node, exact = exact)
    })
}

#' Delete a schema group from a container node
#'
#' @param x A `SchemaDoc`.
#' @param index 1-based group index to remove.
#' @param path Path to the target container node. Use `$` for the root node.
#'   Bare field segments such as `$id` implicitly traverse container `fields`. Use
#'   `$fields$id` to write the explicit field path. Backtick-quote field names
#'   that contain path operators, for example ``$`a$b` ``.
#' @param error_if_missing Logical flag indicating whether a missing group should
#'   raise an error.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(list(
#'     check = list(kind = "list"),
#'     groups = list(schema_group(c("x", "y"), schema_check("number")))
#' ))
#' schema
#'
#' schema_del_group(schema, 1)
#'
#' @export
schema_del_group <- S7::new_generic(
    "schema_del_group",
    "x",
    function(x, index, path = "$", error_if_missing = TRUE) {
        S7::S7_dispatch()
    }
)

S7::method(schema_del_group, SchemaDoc) <- function(x, index, path = "$", error_if_missing = TRUE) {
    checkmate::assert_count(index, positive = TRUE)
    checkmate::assert_flag(error_if_missing)

    schema_edit__modify_doc(x, path, function(node) {
        if (!S7::S7_inherits(node, SchemaNodeContainerCmpt)) {
            if (error_if_missing) {
                stop(sprintf("Group %d does not exist at `%s`.", index, path), call. = FALSE)
            }
            return(node)
        }

        group_idx <- which(vapply(node@exact, function(binding) length(binding@keys) > 1L, logical(1L)))
        if (index > length(group_idx)) {
            if (error_if_missing) {
                stop(sprintf("Group %d does not exist at `%s`.", index, path), call. = FALSE)
            }
            return(node)
        }

        exact <- node@exact
        exact[[group_idx[[index]]]] <- NULL
        schema_edit__update_node(node, exact = exact)
    })
}

#' Delete a container rest schema
#'
#' @param x A `SchemaDoc`.
#' @param path Path to the target container node. Use `$` for the root node.
#'   Bare field segments such as `$id` implicitly traverse container `fields`. Use
#'   `$fields$id` to write the explicit field path. Backtick-quote field names
#'   that contain path operators, for example ``$`a$b` ``.
#' @param error_if_missing Logical flag indicating whether a missing `rest`
#'   schema should raise an error.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(list(check = list(kind = "list")))
#' schema <- schema_set_rest(schema, schema_check("string"))
#' schema <- schema_del_rest(schema)
#' schema
#'
#' as.list(schema)$rest
#'
#' @export
schema_del_rest <- S7::new_generic(
    "schema_del_rest",
    "x",
    function(x, path = "$", error_if_missing = TRUE) {
        S7::S7_dispatch()
    }
)

S7::method(schema_del_rest, SchemaDoc) <- function(x, path = "$", error_if_missing = TRUE) {
    checkmate::assert_flag(error_if_missing)

    schema_edit__modify_doc(x, path, function(node) {
        if (!S7::S7_inherits(node, SchemaNodeContainerCmpt) || is.null(node@rest)) {
            if (error_if_missing) {
                stop(sprintf("Rest schema does not exist at `%s`.", path), call. = FALSE)
            }
            return(node)
        }

        schema_edit__update_node(node, rest = NULL)
    })
}

#' Delete a position schema from an unnamed container node
#'
#' @param x A `SchemaDoc`.
#' @param index 1-based position index to remove.
#' @param path Path to the target unnamed container node. Use `$` for the root
#'   node.
#' @param error_if_missing Logical flag indicating whether a missing position
#'   schema should raise an error.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(list(check = list(kind = "list"), keys = list(type = "unnamed")))
#' schema <- schema_add_position(schema, 1, schema_check("string"))
#' schema <- schema_del_position(schema, 1)
#' schema
#'
#' as.list(schema)$positions
#'
#' @export
schema_del_position <- S7::new_generic(
    "schema_del_position",
    "x",
    function(x, index, path = "$", error_if_missing = TRUE) {
        S7::S7_dispatch()
    }
)

S7::method(schema_del_position, SchemaDoc) <- function(x, index, path = "$", error_if_missing = TRUE) {
    checkmate::assert_count(index, positive = TRUE)
    checkmate::assert_flag(error_if_missing)

    schema_edit__modify_doc(x, path, function(node) {
        if (!S7::S7_inherits(node, SchemaNodeContainerCmpt) || index > length(node@positions)) {
            if (error_if_missing) {
                stop(sprintf("Position %d does not exist at `%s`.", index, path), call. = FALSE)
            }
            return(node)
        }

        positions <- node@positions
        positions[[index]] <- NULL
        schema_edit__update_node(node, positions = positions)
    })
}

#' Add a schema definition
#'
#' @param x A `SchemaDoc`.
#' @param name Definition name to add.
#' @param value Schema fragment using the same list syntax accepted by
#'   `schema_doc()`, or a fragment produced by helpers such as `schema_check()`,
#'   to store in `$defs`.
#' @param overwrite Logical flag indicating whether an existing definition of the
#'   same name should be replaced.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(schema_check("string"))
#' schema <- schema_add_def(schema, "text", schema_check("string"))
#' schema
#'
#' names(as.list(schema)$`$defs`)
#'
#' @export
schema_add_def <- S7::new_generic(
    "schema_add_def",
    "x",
    function(x, name, value, overwrite = FALSE) {
        S7::S7_dispatch()
    }
)

S7::method(schema_add_def, SchemaDoc) <- function(x, name, value, overwrite = FALSE) {
    checkmate::assert_string(name, min.chars = 1L)
    checkmate::assert_flag(overwrite)
    doc <- x
    if (grepl("/", name, fixed = TRUE)) {
        stop("`name` must not contain `/`.", call. = FALSE)
    }
    if (!overwrite && !is.null(doc@defs[[name]])) {
        stop(sprintf("Definition `%s` already exists.", name), call. = FALSE)
    }

    defs_names <- names(doc@defs)
    if (!name %in% defs_names) {
        defs_names <- c(defs_names, name)
    }
    value <- schema_edit__as_node(
        value,
        defs = defs_names,
        path = sprintf("$`$defs`[['%s']]", name),
        context = sprintf("Invalid schema definition `%s`.", name)
    )

    defs <- doc@defs
    defs[[name]] <- value
    schema_edit__update_node(doc, defs = defs)
}

#' Delete a schema definition
#'
#' @param x A `SchemaDoc`.
#' @param name Definition name to remove.
#' @param error_if_missing Logical flag indicating whether a missing definition
#'   should raise an error.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_doc(schema_check("string"))
#' schema <- schema_add_def(schema, "text", schema_check("string"))
#' schema <- schema_del_def(schema, "text")
#' schema
#'
#' as.list(schema)$`$defs`
#'
#' @export
schema_del_def <- S7::new_generic(
    "schema_del_def",
    "x",
    function(x, name, error_if_missing = TRUE) {
        S7::S7_dispatch()
    }
)

S7::method(schema_del_def, SchemaDoc) <- function(x, name, error_if_missing = TRUE) {
    checkmate::assert_string(name, min.chars = 1L)
    checkmate::assert_flag(error_if_missing)

    doc <- x
    if (is.null(doc@defs[[name]])) {
        if (error_if_missing) {
            stop(sprintf("Definition `%s` does not exist.", name), call. = FALSE)
        }
        return(doc)
    }

    defs <- doc@defs
    defs[[name]] <- NULL

    refs <- c(schema_edit__node_refs(doc@root), unlist(lapply(defs, schema_edit__node_refs), use.names = FALSE))
    missing_refs <- setdiff(sub("^#/\\$defs/", "", refs), names(defs))
    if (length(missing_refs)) {
        stop(sprintf("Definition `%s` is still referenced.", missing_refs[[1L]]), call. = FALSE)
    }

    schema_edit__update_node(doc, defs = defs)
}

# vim: fdm=marker :
