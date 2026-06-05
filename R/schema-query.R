#' @include schema-edit.R

schema_query__is_node <- function(x) {
    S7::S7_inherits(x, SchemaNode)
}

schema_query__collect_node <- S7::new_generic(
    "schema_query__collect_node",
    "node",
    function(node, path, emit) S7::S7_dispatch()
)

schema_query__collect_terminal <- function(node, path, emit) {
    emit(path, node)
}

S7::method(schema_query__collect_node, SchemaNodeLeaf) <- schema_query__collect_terminal
S7::method(schema_query__collect_node, SchemaNodeRef) <- schema_query__collect_terminal

schema_query__collect_container <- function(node, path, emit) {
    emit(path, node)

    for (binding in node@exact) {
        for (key in binding@keys) {
            schema_query__collect_node(
                binding@target,
                schema_edit__path_append_field(path, key),
                emit
            )
        }
    }

    for (binding in node@patterns) {
        pattern_path <- schema_edit__path_append(path, "patterns", binding@pattern)
        schema_query__collect_node(binding@target, pattern_path, emit)
    }

    for (i in seq_along(node@positions)) {
        schema_query__collect_node(
            node@positions[[i]],
            schema_edit__path_append_index(path, "positions", i),
            emit
        )
    }

    if (!is.null(node@rest)) {
        schema_query__collect_node(node@rest, schema_edit__path_append(path, "rest"), emit)
    }

    invisible(NULL)
}

S7::method(schema_query__collect_node, SchemaNodeContainerCmpt) <- schema_query__collect_container
S7::method(schema_query__collect_node, SchemaNodeContainerFlat) <- schema_query__collect_container

schema_query__collect_nary <- function(node, path, emit) {
    emit(path, node)

    operator <- schema_query__nary_operator(node)
    for (i in seq_along(node@branches)) {
        schema_query__collect_node(
            node@branches[[i]],
            schema_edit__path_append_index(path, operator, i),
            emit
        )
    }

    invisible(NULL)
}

S7::method(schema_query__collect_node, SchemaNodeNaryCmpt) <- schema_query__collect_nary
S7::method(schema_query__collect_node, SchemaNodeNaryFlat) <- schema_query__collect_nary

schema_query__collect_not <- function(node, path, emit) {
    emit(path, node)
    schema_query__collect_node(node@branch, schema_edit__path_append(path, "not"), emit)
    invisible(NULL)
}

S7::method(schema_query__collect_node, SchemaNodeNotCmpt) <- schema_query__collect_not
S7::method(schema_query__collect_node, SchemaNodeNotFlat) <- schema_query__collect_not

schema_query__nary_operator <- function(node) {
    if (S7::S7_inherits(node, SchemaNodeAllCmpt) || S7::S7_inherits(node, SchemaNodeAllFlat)) {
        "all"
    } else if (S7::S7_inherits(node, SchemaNodeAnyCmpt) || S7::S7_inherits(node, SchemaNodeAnyFlat)) {
        "any"
    } else if (S7::S7_inherits(node, SchemaNodeOneCmpt) || S7::S7_inherits(node, SchemaNodeOneFlat)) {
        "one"
    } else {
        stop("Unsupported n-ary schema node type.", call. = FALSE)
    }
}

schema_query__walk_doc <- function(doc, defs, emit) {
    schema_query__collect_node(doc@root, "$", emit)
    if (defs && length(doc@defs)) {
        for (name in names(doc@defs)) {
            schema_query__collect_node(
                doc@defs[[name]],
                schema_edit__path_append("$", "defs", name),
                emit
            )
        }
    }

    invisible(NULL)
}

schema_query__walk <- function(x, defs = TRUE, emit) {
    checkmate::assert_flag(defs)

    if (S7::S7_inherits(x, SchemaDoc)) {
        return(schema_query__walk_doc(x, defs = defs, emit = emit))
    }

    if (S7::S7_inherits(x, SchemaFlat)) {
        schema_query__collect_node(x@root, "$", emit)
        return(invisible(NULL))
    }

    if (schema_query__is_node(x)) {
        schema_query__collect_node(x, "$", emit)
        return(invisible(NULL))
    }

    schema_query__walk_doc(schema_doc(x), defs = defs, emit = emit)
}

schema_query__assert_predicate_result <- function(result, path) {
    if (!is.logical(result) || length(result) != 1L || is.na(result)) {
        stop(sprintf("`where` must return a single TRUE or FALSE at path `%s`.", path), call. = FALSE)
    }
    result
}

schema_query__call_where <- function(where, path, node) {
    result <- tryCatch(
        where(path, node),
        error = function(e) {
            stop(
                sprintf("Failed to evaluate `where` at path `%s`.\n%s", path, conditionMessage(e)),
                call. = FALSE
            )
        }
    )
    schema_query__assert_predicate_result(result, path)
}

schema_query__call_fn <- function(fn, path, node) {
    tryCatch(
        fn(path, node),
        error = function(e) {
            stop(
                sprintf("Failed to modify schema node at path `%s`.\n%s", path, conditionMessage(e)),
                call. = FALSE
            )
        }
    )
}

schema_query__rewrite_state <- function() {
    new.env(parent = emptyenv())
}

schema_query__rewrite_result <- function(node, changed = FALSE) {
    list(node = node, changed = changed)
}

schema_query__compile_flat_replacement <- function(node, path, context) {
    if (schema_flat__node_is_flat(node)) {
        return(node)
    }

    tryCatch(
        schema_flat__compile(SchemaDoc(root = node, defs = list()))@root,
        error = function(e) {
            schema_edit__abort_with_context(context, e)
        }
    )
}

schema_query__replace_current <- function(node, path, fn, defs, flat) {
    value <- schema_query__call_fn(fn, path, node)
    context <- sprintf("Invalid replacement at path `%s`.", path)
    replacement <- schema_edit__as_node(
        value,
        defs = defs,
        path = path,
        context = context
    )

    if (flat) {
        return(schema_query__compile_flat_replacement(replacement, path = path, context = context))
    }

    replacement
}

schema_query__check_match <- function(where, path, node, state, ancestor) {
    matched <- schema_query__call_where(where, path, node)
    if (matched && !is.null(ancestor)) {
        stop(
            sprintf(
                "`where` matched both ancestor path `%s` and descendant path `%s`; please narrow the selector.",
                ancestor,
                path
            ),
            call. = FALSE
        )
    }
    if (matched) {
        state$count <- state$count + 1L
    }
    matched
}

schema_query__rewrite_node <- S7::new_generic(
    "schema_query__rewrite_node",
    "node",
    function(node, path, where, fn, defs, state, ancestor = NULL, flat = FALSE) S7::S7_dispatch()
)

schema_query__rewrite_terminal <- function(
    node,
    path,
    where,
    fn,
    defs,
    state,
    ancestor = NULL,
    flat = FALSE
) {
    matched <- schema_query__check_match(where, path, node, state, ancestor)
    if (matched) {
        return(schema_query__rewrite_result(
            schema_query__replace_current(node, path, fn, defs, flat = flat),
            changed = TRUE
        ))
    }

    schema_query__rewrite_result(node)
}

S7::method(schema_query__rewrite_node, SchemaNodeLeaf) <- schema_query__rewrite_terminal
S7::method(schema_query__rewrite_node, SchemaNodeRef) <- schema_query__rewrite_terminal

schema_query__rewrite_container <- function(
    node,
    path,
    where,
    fn,
    defs,
    state,
    ancestor,
    flat,
    exact_constructor,
    pattern_constructor
) {
    matched <- schema_query__check_match(where, path, node, state, ancestor)
    next_ancestor <- if (matched) path else ancestor

    exact <- list()
    exact_changed <- FALSE
    for (binding in node@exact) {
        key_results <- lapply(binding@keys, function(key) {
            schema_query__rewrite_node(
                binding@target,
                schema_edit__path_append_field(path, key),
                where = where,
                fn = fn,
                defs = defs,
                state = state,
                ancestor = next_ancestor,
                flat = flat
            )
        })
        binding_changed <- any(vapply(key_results, function(result) result$changed, logical(1L)))
        exact_changed <- exact_changed || binding_changed

        if (binding_changed) {
            for (i in seq_along(binding@keys)) {
                exact[[length(exact) + 1L]] <- exact_constructor(
                    keys = binding@keys[[i]],
                    target = key_results[[i]]$node
                )
            }
        } else {
            exact[[length(exact) + 1L]] <- binding
        }
    }

    patterns <- node@patterns
    patterns_changed <- FALSE
    if (length(patterns)) {
        for (i in seq_along(patterns)) {
            binding <- patterns[[i]]
            result <- schema_query__rewrite_node(
                binding@target,
                schema_edit__path_append(path, "patterns", binding@pattern),
                where = where,
                fn = fn,
                defs = defs,
                state = state,
                ancestor = next_ancestor,
                flat = flat
            )
            if (result$changed) {
                patterns[[i]] <- pattern_constructor(pattern = binding@pattern, target = result$node)
                patterns_changed <- TRUE
            }
        }
    }

    positions <- node@positions
    positions_changed <- FALSE
    if (length(positions)) {
        for (i in seq_along(positions)) {
            result <- schema_query__rewrite_node(
                positions[[i]],
                schema_edit__path_append_index(path, "positions", i),
                where = where,
                fn = fn,
                defs = defs,
                state = state,
                ancestor = next_ancestor,
                flat = flat
            )
            if (result$changed) {
                positions[[i]] <- result$node
                positions_changed <- TRUE
            }
        }
    }

    rest <- node@rest
    rest_changed <- FALSE
    if (!is.null(rest)) {
        result <- schema_query__rewrite_node(
            rest,
            schema_edit__path_append(path, "rest"),
            where = where,
            fn = fn,
            defs = defs,
            state = state,
            ancestor = next_ancestor,
            flat = flat
        )
        if (result$changed) {
            rest <- result$node
            rest_changed <- TRUE
        }
    }

    if (matched) {
        return(schema_query__rewrite_result(
            schema_query__replace_current(node, path, fn, defs, flat = flat),
            changed = TRUE
        ))
    }

    if (exact_changed || patterns_changed || positions_changed || rest_changed) {
        node <- schema_edit__update_node(
            node,
            exact = exact,
            patterns = patterns,
            positions = positions,
            rest = rest
        )
        return(schema_query__rewrite_result(node, changed = TRUE))
    }

    schema_query__rewrite_result(node)
}

schema_query__rewrite_container_method <- function(
    node,
    path,
    where,
    fn,
    defs,
    state,
    ancestor = NULL,
    flat = FALSE
) {
    flat <- schema_flat__node_is_flat(node)
    exact_constructor <- if (flat) SchemaBindingExactFlat else SchemaBindingExactCmpt
    pattern_constructor <- if (flat) SchemaBindingPatternFlat else SchemaBindingPatternCmpt

    schema_query__rewrite_container(
        node,
        path = path,
        where = where,
        fn = fn,
        defs = defs,
        state = state,
        ancestor = ancestor,
        flat = flat,
        exact_constructor = exact_constructor,
        pattern_constructor = pattern_constructor
    )
}

S7::method(schema_query__rewrite_node, SchemaNodeContainerCmpt) <- schema_query__rewrite_container_method
S7::method(schema_query__rewrite_node, SchemaNodeContainerFlat) <- schema_query__rewrite_container_method

schema_query__rewrite_nary <- function(
    node,
    path,
    where,
    fn,
    defs,
    state,
    ancestor = NULL,
    flat = FALSE
) {
    flat <- schema_flat__node_is_flat(node)
    matched <- schema_query__check_match(where, path, node, state, ancestor)
    next_ancestor <- if (matched) path else ancestor
    operator <- schema_query__nary_operator(node)

    branches <- node@branches
    changed <- FALSE
    for (i in seq_along(branches)) {
        result <- schema_query__rewrite_node(
            branches[[i]],
            schema_edit__path_append_index(path, operator, i),
            where = where,
            fn = fn,
            defs = defs,
            state = state,
            ancestor = next_ancestor,
            flat = flat
        )
        if (result$changed) {
            branches[[i]] <- result$node
            changed <- TRUE
        }
    }

    if (matched) {
        return(schema_query__rewrite_result(
            schema_query__replace_current(node, path, fn, defs, flat = flat),
            changed = TRUE
        ))
    }

    if (changed) {
        return(schema_query__rewrite_result(schema_edit__update_node(node, branches = branches), changed = TRUE))
    }

    schema_query__rewrite_result(node)
}

S7::method(schema_query__rewrite_node, SchemaNodeNaryCmpt) <- schema_query__rewrite_nary
S7::method(schema_query__rewrite_node, SchemaNodeNaryFlat) <- schema_query__rewrite_nary

schema_query__rewrite_not <- function(
    node,
    path,
    where,
    fn,
    defs,
    state,
    ancestor = NULL,
    flat = FALSE
) {
    flat <- schema_flat__node_is_flat(node)
    matched <- schema_query__check_match(where, path, node, state, ancestor)
    next_ancestor <- if (matched) path else ancestor

    result <- schema_query__rewrite_node(
        node@branch,
        schema_edit__path_append(path, "not"),
        where = where,
        fn = fn,
        defs = defs,
        state = state,
        ancestor = next_ancestor,
        flat = flat
    )

    if (matched) {
        return(schema_query__rewrite_result(
            schema_query__replace_current(node, path, fn, defs, flat = flat),
            changed = TRUE
        ))
    }

    if (result$changed) {
        return(schema_query__rewrite_result(schema_edit__update_node(node, branch = result$node), changed = TRUE))
    }

    schema_query__rewrite_result(node)
}

S7::method(schema_query__rewrite_node, SchemaNodeNotCmpt) <- schema_query__rewrite_not
S7::method(schema_query__rewrite_node, SchemaNodeNotFlat) <- schema_query__rewrite_not

schema_query__rewrite_doc <- function(doc, where, fn, include_defs) {
    state <- schema_query__rewrite_state()
    state$count <- 0L
    defs <- names(doc@defs)

    root <- schema_query__rewrite_node(
        doc@root,
        path = "$",
        where = where,
        fn = fn,
        defs = defs,
        state = state,
        flat = FALSE
    )

    defs_list <- doc@defs
    defs_changed <- FALSE
    if (include_defs && length(defs_list)) {
        for (name in names(defs_list)) {
            result <- schema_query__rewrite_node(
                defs_list[[name]],
                path = schema_edit__path_append("$", "defs", name),
                where = where,
                fn = fn,
                defs = defs,
                state = state,
                flat = FALSE
            )
            if (result$changed) {
                defs_list[[name]] <- result$node
                defs_changed <- TRUE
            }
        }
    }

    list(
        value = if (root$changed || defs_changed) {
            schema_edit__update_node(doc, root = root$node, defs = defs_list)
        } else {
            doc
        },
        count = state$count
    )
}

schema_query__rewrite_flat <- function(flat, where, fn) {
    state <- schema_query__rewrite_state()
    state$count <- 0L

    root <- schema_query__rewrite_node(
        flat@root,
        path = "$",
        where = where,
        fn = fn,
        defs = character(),
        state = state,
        flat = TRUE
    )

    list(
        value = if (root$changed) {
            schema_edit__update_node(flat, root = root$node)
        } else {
            flat
        },
        count = state$count
    )
}

schema_query__rewrite_bare_node <- function(node, where, fn) {
    state <- schema_query__rewrite_state()
    state$count <- 0L
    flat <- schema_flat__node_is_flat(node)

    result <- schema_query__rewrite_node(
        node,
        path = "$",
        where = where,
        fn = fn,
        defs = character(),
        state = state,
        flat = flat
    )

    list(
        value = result$node,
        count = state$count
    )
}

schema_query__rewrite_input <- function(x, where, fn, defs) {
    if (S7::S7_inherits(x, SchemaDoc)) {
        return(schema_query__rewrite_doc(x, where = where, fn = fn, include_defs = defs))
    }

    if (S7::S7_inherits(x, SchemaFlat)) {
        return(schema_query__rewrite_flat(x, where = where, fn = fn))
    }

    if (schema_query__is_node(x)) {
        return(schema_query__rewrite_bare_node(x, where = where, fn = fn))
    }

    schema_query__rewrite_doc(schema_doc(x), where = where, fn = fn, include_defs = defs)
}

#' Query schema paths and matching nodes
#'
#' `schema_paths()` lists editable logical schema paths. `schema_find()` returns
#' paths whose schema node satisfies a predicate.
#'
#' Logical paths describe fields as users see them in the validated data. Grouped
#' fields are expanded to one path per field.
#'
#' @param x A schema document or raw schema DSL list.
#' @param defs Whether to include root `$defs` entries.
#' @param where Predicate function with signature `function(path, node)`.
#'
#' @return A character vector of schema paths.
#'
#' @examples
#' schema <- schema_compact(schema_infer(list(
#'     issued = list(`date-parts` = list(list(2024L))),
#'     created = list(`date-parts` = list(list(2024L)))
#' ), arrays = "rest"))
#' schema
#'
#' schema_find(schema, schema_where_path("(^|\\$)`date-parts`\\$rest$"))
#' schema_find(schema, schema_where_check("int"))
#'
#' @export
schema_paths <- function(x, defs = TRUE) {
    paths <- character()
    schema_query__walk(x, defs = defs, emit = function(path, node) {
        paths[[length(paths) + 1L]] <<- path
        invisible(NULL)
    })
    paths
}

#' @rdname schema_paths
#' @export
schema_find <- function(x, where, defs = TRUE) {
    checkmate::assert_function(where)
    paths <- character()
    schema_query__walk(x, defs = defs, emit = function(path, node) {
        if (schema_query__call_where(where, path, node)) {
            paths[[length(paths) + 1L]] <<- path
        }
        invisible(NULL)
    })
    paths
}

#' Modify schema nodes selected by a predicate
#'
#' `schema_modify_where()` modifies every schema node matched by `where`.
#' `schema_replace_where()` is a convenience wrapper that replaces all matched
#' nodes with the same schema fragment.
#'
#' Batch edits operate on logical paths. Editing paths inside a grouped schema
#' field may split the group into per-field bindings. If `where` matches both a
#' node and one of its descendants in the same call, the edit errors and asks you
#' to narrow the selector.
#'
#' @param x A schema document or raw schema DSL list.
#' @param where Predicate function with signature `function(path, node)`.
#' @param fn Function with signature `function(path, node)` returning a schema
#'   fragment or `SchemaNode`.
#' @param value Replacement schema fragment or `SchemaNode`.
#' @param defs Whether to include root `$defs` entries.
#' @param missing Missing-match behavior. Use `"error"` to raise an error when
#'   `where` matches no paths or `"ignore"` to leave the schema unchanged.
#'
#' @return A modified `SchemaDoc`.
#'
#' @examples
#' schema <- schema_compact(schema_infer(list(
#'     issued = list(`date-parts` = list(list(2024L))),
#'     created = list(`date-parts` = list(list(2024L)))
#' ), arrays = "rest"))
#' schema <- schema_add_def(schema, "year", schema_check("int", lower = 0))
#' schema
#'
#' schema_find(schema, schema_where_path("(^|\\$)`date-parts`\\$rest$"))
#'
#' schema <- schema_replace_where(
#'     schema,
#'     schema_where_path("(^|\\$)`date-parts`\\$rest$"),
#'     schema_ref("year")
#' )
#' schema
#'
#' @export
schema_modify_where <- function(x, where, fn, defs = TRUE, missing = "ignore") {
    checkmate::assert_function(where)
    checkmate::assert_function(fn)
    checkmate::assert_flag(defs)
    missing <- match.arg(missing, c("error", "ignore"))

    result <- schema_query__rewrite_input(x, where, fn, defs = defs)
    if (!result$count && identical(missing, "error")) {
        stop("`where` did not match any schema paths.", call. = FALSE)
    }

    result$value
}

#' @rdname schema_modify_where
#' @export
schema_replace_where <- function(x, where, value, defs = TRUE, missing = "ignore") {
    force(value)
    schema_modify_where(
        x,
        where,
        function(path, node) value,
        defs = defs,
        missing = missing
    )
}

#' Create schema query predicates
#'
#' @param pattern Pattern passed to `grepl()` for matching schema paths.
#' @param fixed Whether `pattern` should be matched literally.
#' @param kind Optional check kind to match, such as `"list"` or `"int"`.
#'
#' @return A predicate function with signature `function(path, node)`.
#'
#' @examples
#' by_path <- schema_where_path("(^|\\$)`date-parts`\\$rest$")
#' by_int <- schema_where_check("int")
#'
#' schema <- schema_infer(list(id = 1L))
#' schema
#'
#' schema_find(schema, by_int)
#'
#' @export
schema_where_path <- function(pattern, fixed = FALSE) {
    checkmate::assert_string(pattern, min.chars = 1L)
    checkmate::assert_flag(fixed)

    function(path, node) {
        grepl(pattern, path, fixed = fixed, useBytes = TRUE)
    }
}

#' @rdname schema_where_path
#' @export
schema_where_check <- function(kind = NULL) {
    checkmate::assert_string(kind, min.chars = 1L, null.ok = TRUE)
    if (!is.null(kind) && !kind %in% SCHEMA_SPEC_KINDS) {
        stop(sprintf("Unsupported check kind `%s`.", kind), call. = FALSE)
    }

    function(path, node) {
        S7::S7_inherits(node, SchemaNodeCheck) && (is.null(kind) || identical(node@value@kind, kind))
    }
}

# vim: fdm=marker :
