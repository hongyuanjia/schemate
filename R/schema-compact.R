#' @include schema-doc.R
#' @noRd
NULL

schema_compact__normalize_check_rule <- function(x) {
    if (!is.list(x) || is.null(x$kind)) {
        return(x)
    }

    fun <- tryCatch(
        schema_utils__checkmate_fun(x$kind),
        error = function(e) NULL
    )
    if (is.null(fun)) {
        return(x)
    }

    defaults <- as.list(formals(fun))
    out <- list(kind = x$kind)
    args <- x[names(x) != "kind"]
    matched <- match.call(
        definition = fun,
        call = as.call(c(list(quote(check), quote(.x)), args)),
        expand.dots = TRUE
    )
    matched <- as.list(matched)[-1L]
    matched$x <- NULL

    for (name in names(matched)) {
        if (name %in% names(defaults) && identical(matched[[name]], defaults[[name]])) {
            next
        }
        out[[name]] <- matched[[name]]
    }

    out
}

schema_compact__normalize_schema_list <- function(x) {
    if (!is.list(x)) {
        return(x)
    }

    out <- lapply(x, schema_compact__normalize_schema_list)
    if (!is.null(out$check)) {
        out$check <- schema_compact__normalize_check_rule(out$check)
    }
    out
}

schema_compact__dedupe_equivalent_nodes <- function(x) {
    if (!length(x)) {
        return(x)
    }

    x[!duplicated(lapply(x, function(node) schema_compact__normalize_schema_list(as.list(node))))]
}

schema_compact__same_node <- function(x, y) {
    identical(
        schema_compact__normalize_schema_list(as.list(x)),
        schema_compact__normalize_schema_list(as.list(y))
    )
}

schema_compact__same_node_list <- function(x, y) {
    length(x) == length(y) &&
        identical(
            lapply(x, function(node) schema_compact__normalize_schema_list(as.list(node))),
            lapply(y, function(node) schema_compact__normalize_schema_list(as.list(node)))
        )
}

schema_compact__same_patterns <- function(x, y) {
    length(x) == length(y) &&
        identical(
            vapply(x, function(binding) binding@pattern, character(1L)),
            vapply(y, function(binding) binding@pattern, character(1L))
        ) &&
        identical(
            lapply(x, function(binding) schema_compact__normalize_schema_list(as.list(binding@target))),
            lapply(y, function(binding) schema_compact__normalize_schema_list(as.list(binding@target)))
        )
}

schema_compact__name_type <- function(x) {
    if (is.null(x)) {
        return(NA_character_)
    }

    schema_utils__coalesce(x@args$type, NA_character_)
}

schema_compact__name_required <- function(x) {
    if (is.null(x)) {
        return(character())
    }

    if (!is.null(x@args$identical.to)) {
        return(x@args$identical.to)
    }

    schema_utils__coalesce(x@args$must.include, character())
}

schema_compact__names_mergeable <- function(x) {
    types <- vapply(x, schema_compact__name_type, character(1L), USE.NAMES = FALSE)
    types <- types[!is.na(types)]

    if (!length(types)) {
        return(TRUE)
    }

    all(types == types[[1L]])
}

schema_compact__merge_name <- function(x) {
    x <- Filter(Negate(is.null), x)
    if (!length(x)) {
        return(NULL)
    }

    types <- vapply(x, schema_compact__name_type, character(1L), USE.NAMES = FALSE)
    types <- types[!is.na(types)]
    if (length(types) && all(types == types[[1L]]) && identical(types[[1L]], "unnamed")) {
        return(SchemaRuleNames(args = list(type = "unnamed")))
    }

    exact <- lapply(x, function(rule) rule@args$identical.to)
    if (all(!vapply(exact, is.null, logical(1L))) && all(vapply(exact[-1L], identical, logical(1L), exact[[1L]]))) {
        return(SchemaRuleNames(args = list(identical.to = exact[[1L]])))
    }

    required <- lapply(x, schema_compact__name_required)
    must_include <- Reduce(intersect, required)
    args <- list(type = "named")
    if (length(must_include)) {
        args$must.include <- must_include
    }
    SchemaRuleNames(args = args)
}

schema_compact__binding_field_map <- function(exact) {
    out <- list()
    for (binding in exact) {
        for (key in binding@keys) {
            out[[key]] <- binding@target
        }
    }

    out
}

schema_compact__merge_node_options <- function(nodes, arrays, groups) {
    nodes <- schema_compact__dedupe_equivalent_nodes(nodes)
    if (!length(nodes)) {
        return(NULL)
    }
    if (length(nodes) == 1L) {
        return(nodes[[1L]])
    }

    schema_compact__compact_any(nodes, desc = NULL, arrays = arrays, groups = groups)
}

schema_compact__merge_field_maps <- function(maps, arrays, groups) {
    keys <- unique(unlist(lapply(maps, names), use.names = FALSE))
    if (!length(keys)) {
        return(list())
    }

    unname(lapply(keys, function(key) {
        targets <- Filter(
            Negate(is.null),
            lapply(maps, function(map) map[[key]])
        )
        SchemaBindingExactCmpt(
            keys = key,
            target = schema_compact__merge_node_options(targets, arrays = arrays, groups = groups)
        )
    }))
}

schema_compact__merge_rest <- function(x, arrays, groups) {
    rest <- Filter(Negate(is.null), lapply(x, function(node) node@rest))
    if (!length(rest)) {
        return(NULL)
    }

    schema_compact__merge_node_options(rest, arrays = arrays, groups = groups)
}

schema_compact__containers_can_merge <- function(x, y) {
    identical(as.list(x@value), as.list(y@value)) &&
        schema_compact__names_mergeable(list(x@name, y@name)) &&
        schema_compact__same_patterns(x@patterns, y@patterns) &&
        schema_compact__same_node_list(x@positions, y@positions)
}

schema_compact__merge_containers <- function(x, arrays, groups) {
    first <- x[[1L]]
    exact <- schema_compact__merge_field_maps(
        lapply(x, function(node) schema_compact__binding_field_map(node@exact)),
        arrays = arrays,
        groups = groups
    )

    node <- SchemaNodeContainerCmpt(
        value = first@value,
        name = schema_compact__merge_name(lapply(x, function(node) node@name)),
        exact = exact,
        patterns = first@patterns,
        positions = first@positions,
        rest = schema_compact__merge_rest(x, arrays = arrays, groups = groups),
        # Descriptions are not part of merge compatibility; keep the first one.
        desc = first@desc
    )

    schema_compact__compact_container_groups(node, groups = groups)
}

schema_compact__merge_compatible_containers <- function(branches, arrays, groups) {
    used <- rep(FALSE, length(branches))
    out <- list()

    for (i in seq_along(branches)) {
        if (used[[i]]) {
            next
        }

        branch <- branches[[i]]
        if (!S7::S7_inherits(branch, SchemaNodeContainerCmpt)) {
            out[[length(out) + 1L]] <- branch
            used[[i]] <- TRUE
            next
        }

        idx <- i
        if (i < length(branches)) {
            for (j in seq.int(i + 1L, length(branches))) {
                if (!used[[j]] && S7::S7_inherits(branches[[j]], SchemaNodeContainerCmpt) &&
                    schema_compact__containers_can_merge(branch, branches[[j]])) {
                    idx <- c(idx, j)
                }
            }
        }

        used[idx] <- TRUE
        out[[length(out) + 1L]] <- if (length(idx) == 1L) {
            branch
        } else {
            schema_compact__merge_containers(branches[idx], arrays = arrays, groups = groups)
        }
    }

    out
}

schema_compact__compact_any <- function(branches, desc, arrays, groups) {
    branches <- schema_compact__dedupe_equivalent_nodes(branches)
    if (arrays) {
        branches <- schema_compact__merge_compatible_containers(branches, arrays = arrays, groups = groups)
        branches <- schema_compact__dedupe_equivalent_nodes(branches)
    }

    if (length(branches) == 1L && is.null(desc)) {
        return(branches[[1L]])
    }

    SchemaNodeAnyCmpt(branches = branches, desc = desc)
}

schema_compact__compact_container_groups <- function(node, groups) {
    if (!groups || !length(node@exact) || identical(schema_compact__name_type(node@name), "unnamed")) {
        return(node)
    }

    grouped <- list()
    for (binding in node@exact) {
        index <- NA_integer_
        for (i in seq_along(grouped)) {
            if (schema_compact__same_node(grouped[[i]]$target, binding@target)) {
                index <- i
                break
            }
        }
        if (is.na(index)) {
            grouped[[length(grouped) + 1L]] <- list(keys = character(), target = binding@target)
            index <- length(grouped)
        }
        grouped[[index]]$keys <- c(grouped[[index]]$keys, binding@keys)
    }

    exact <- unname(lapply(grouped, function(group) {
        SchemaBindingExactCmpt(
            keys = unique(group$keys),
            target = group$target
        )
    }))

    S7::set_props(node, exact = exact)
}

schema_compact__node <- S7::new_generic(
    "schema_compact__node",
    "node",
    function(node, arrays, groups) S7::S7_dispatch()
)

S7::method(schema_compact__node, SchemaNodeLeaf) <- function(node, arrays, groups) {
    node
}

S7::method(schema_compact__node, SchemaNodeRef) <- function(node, arrays, groups) {
    node
}

S7::method(schema_compact__node, SchemaNodeContainerCmpt) <- function(node, arrays, groups) {
    exact <- lapply(node@exact, function(binding) {
        SchemaBindingExactCmpt(
            keys = binding@keys,
            target = schema_compact__node(binding@target, arrays = arrays, groups = groups)
        )
    })
    patterns <- lapply(node@patterns, function(binding) {
        SchemaBindingPatternCmpt(
            pattern = binding@pattern,
            target = schema_compact__node(binding@target, arrays = arrays, groups = groups)
        )
    })
    positions <- lapply(node@positions, schema_compact__node, arrays = arrays, groups = groups)
    rest <- if (is.null(node@rest)) {
        NULL
    } else {
        schema_compact__node(node@rest, arrays = arrays, groups = groups)
    }

    compacted <- SchemaNodeContainerCmpt(
        value = node@value,
        name = node@name,
        exact = exact,
        patterns = patterns,
        positions = positions,
        rest = rest,
        desc = node@desc
    )
    schema_compact__compact_container_groups(compacted, groups = groups)
}

S7::method(schema_compact__node, SchemaNodeAllCmpt) <- function(node, arrays, groups) {
    SchemaNodeAllCmpt(
        branches = lapply(node@branches, schema_compact__node, arrays = arrays, groups = groups),
        desc = node@desc
    )
}

S7::method(schema_compact__node, SchemaNodeAnyCmpt) <- function(node, arrays, groups) {
    branches <- lapply(node@branches, schema_compact__node, arrays = arrays, groups = groups)
    schema_compact__compact_any(branches, desc = node@desc, arrays = arrays, groups = groups)
}

S7::method(schema_compact__node, SchemaNodeOneCmpt) <- function(node, arrays, groups) {
    SchemaNodeOneCmpt(
        branches = lapply(node@branches, schema_compact__node, arrays = arrays, groups = groups),
        desc = node@desc
    )
}

S7::method(schema_compact__node, SchemaNodeNotCmpt) <- function(node, arrays, groups) {
    SchemaNodeNotCmpt(
        branch = schema_compact__node(node@branch, arrays = arrays, groups = groups),
        desc = node@desc
    )
}

S7::method(schema_compact__node, SchemaNode) <- function(node, arrays, groups) {
    stop("Unsupported schema node.", call. = FALSE)
}

S7::method(schema_compact__node, S7::class_any) <- function(node, arrays, groups) {
    stop("Unsupported schema node.", call. = FALSE)
}

#' Compact a schema document
#'
#' `schema_compact()` simplifies schema documents produced by inference or
#' hand-authoring. It can merge observed array element alternatives and group
#' sibling fields that share identical schemas.
#'
#' @param x A `SchemaDoc` or raw schema DSL list.
#' @param arrays Whether to merge compatible `any` branches, especially the
#'   observed element alternatives produced by `schema_infer(arrays = "rest")`.
#' @param groups Whether to combine sibling fields with identical schemas into
#'   `groups`.
#'
#' @return A compacted `SchemaDoc`.
#'
#' @examples
#' schema <- schema_infer(
#'     list(items = list(list(id = 1L, name = "a"), list(id = 2L, label = "b"))),
#'     keys = "named",
#'     arrays = "rest"
#' )
#' schema
#'
#' compact <- schema_compact(schema)
#' compact
#'
#' names(as.list(compact)$fields$items$rest$fields)
#'
#' @export
schema_compact <- function(x, arrays = TRUE, groups = TRUE) {
    checkmate::assert_flag(arrays)
    checkmate::assert_flag(groups)

    doc <- schema_doc(x)
    defs <- lapply(doc@defs, schema_compact__node, arrays = arrays, groups = groups)

    SchemaDoc(
        version = doc@version,
        path = doc@path,
        root = schema_compact__node(doc@root, arrays = arrays, groups = groups),
        defs = defs
    )
}

# vim: fdm=marker :
