#' @include schema-utils.R

SCHEMA_SPEC_KINDS <- sort(sub("^check_", "", grep("^check_", getNamespaceExports("checkmate"), value = TRUE)))
SCHEMA_SPEC_KINDS_CONTAINER <- c("list", "data_frame", "data_table", "tibble")
SCHEMA_SPEC_OPERATORS <- c("check", "$ref", "all", "any", "one", "not")
SCHEMA_SPEC_KEYWORDS <- c(SCHEMA_SPEC_OPERATORS, "fields", "groups", "patterns", "positions", "rest", "keys", "description", "$defs", "version")

# SchemaSpec {{{
# - node variants become distinct classes instead of a single tagged union
# - rule payload is represented by shared `SchemaRule*` classes
# - exact and pattern bindings are represented by separate classes
# - positions child list represents unnamed prefixItems semantics
# - rest child is made explicit
# - n-ary combinators share common abstract parents
schema_spec__kind_is_container <- function(kind) {
    kind %in% SCHEMA_SPEC_KINDS_CONTAINER
}

SchemaSpec <- S7::new_class("SchemaSpec", abstract = TRUE)

SchemaRule <- S7::new_class(
    "SchemaRule",
    parent = SchemaSpec,
    abstract = TRUE
)

SchemaRuleCheck <- S7::new_class(
    "SchemaRuleCheck",
    parent = SchemaRule,
    properties = list(
        kind = schema_utils__prop_choice(SCHEMA_SPEC_KINDS, null.ok = FALSE),
        args = schema_utils__prop_list(null.ok = FALSE, names = "unique", default = list())
    ),
    validator = function(self) {
        if (length(self@args)) {
            schema_utils__checkmate_result(
                checkmate::check_subset(
                    names(self@args),
                    schema_utils__checkmate_args(self@kind),
                    empty.ok = FALSE
                ),
                sprintf("invalid arguments for check kind `%s`", self@kind)
            )
        }
    }
)

SchemaRuleNames <- S7::new_class(
    "SchemaRuleNames",
    parent = SchemaRule,
    properties = list(
        args = schema_utils__prop_list(null.ok = FALSE, names = "unique", default = list())
    ),
    validator = function(self) {
        if (!length(self@args)) {
            return(NULL)
        }

        schema_utils__checkmate_result(
            checkmate::check_subset(names(self@args), schema_utils__formal_args(checkmate::check_names)[-1L]),
            "invalid arguments for `checkmate::check_names()`"
        )
    }
)

schema_spec__name_type <- function(x) {
    if (is.null(x)) {
        return(NULL)
    }

    x@args$type
}

SchemaNode <- S7::new_class(
    "SchemaNode",
    parent = SchemaSpec,
    properties = list(desc = schema_utils__prop_string()),
    abstract = TRUE
)

SchemaBindingExact <- S7::new_class(
    "SchemaBindingExact",
    parent = SchemaSpec,
    abstract = TRUE,
    properties = list(
        keys = schema_utils__prop_character(any.missing = FALSE, min.len = 1L, unique = TRUE),
        target = S7::new_property(SchemaNode)
    )
)

SchemaBindingExactCmpt <- S7::new_class(
    "SchemaBindingExactCmpt",
    parent = SchemaBindingExact
)

SchemaBindingPattern <- S7::new_class(
    "SchemaBindingPattern",
    parent = SchemaSpec,
    abstract = TRUE,
    properties = list(
        pattern = schema_utils__prop_string(null.ok = FALSE, min.chars = 1L),
        target = S7::new_property(SchemaNode)
    ),
    validator = function(self) {
        ok <- tryCatch({
            grepl(self@pattern, "")
            TRUE
        }, error = function(e) FALSE)
        if (!ok) {
            return(sprintf("`pattern` must be a valid regular expression: %s", self@pattern))
        }
    }
)

SchemaBindingPatternCmpt <- S7::new_class(
    "SchemaBindingPatternCmpt",
    parent = SchemaBindingPattern
)

SchemaNodeCheck <- S7::new_class(
    "SchemaNodeCheck",
    parent = SchemaNode,
    properties = list(
        value = S7::new_property(SchemaRuleCheck),
        name = S7::new_property(
            NULL | SchemaRuleNames,
            default = NULL
        )
    ),
    abstract = TRUE
)

SchemaNodeLeaf <- S7::new_class(
    "SchemaNodeLeaf",
    parent = SchemaNodeCheck,
    validator = function(self) {
        if (schema_spec__kind_is_container(self@value@kind)) {
            return(sprintf(
                "`SchemaNodeLeaf` does not allow container kind `%s`; container kinds are: %s.",
                self@value@kind,
                paste0("'", SCHEMA_SPEC_KINDS_CONTAINER, "'", collapse = ", ")
            ))
        }
    }
)

SchemaNodeContainer <- S7::new_class(
    "SchemaNodeContainer",
    parent = SchemaNodeCheck,
    abstract = TRUE
)

SchemaNodeContainerCmpt <- S7::new_class(
    "SchemaNodeContainerCmpt",
    parent = SchemaNodeContainer,
    properties = list(
        exact = schema_utils__prop_list("SchemaBindingExactCmpt", names = "unnamed", default = list()),
        patterns = schema_utils__prop_list("SchemaBindingPatternCmpt", names = "unnamed", default = list()),
        positions = schema_utils__prop_list("SchemaNode", names = "unnamed", default = list()),
        rest = S7::new_property(NULL | SchemaNode, default = NULL)
    ),
    validator = function(self) {
        if (!schema_spec__kind_is_container(self@value@kind)) {
            return(sprintf(
                "@value requires a container kind; got `%s`. Allowed container kinds are: %s.",
                self@value@kind,
                paste0("'", SCHEMA_SPEC_KINDS_CONTAINER, "'", collapse = ", ")
            ))
        }

        if (length(self@exact)) {
            keys <- unlist(lapply(self@exact, function(x) x@keys), use.names = FALSE)
            msg <- schema_utils__checkmate_result(checkmate::check_character(keys, unique = TRUE), label = "@exact")
            if (!is.null(msg)) {
                return(sprintf("%s ('%s')", msg, keys[duplicated(keys)][[1L]]))
            }
        }

        if (length(self@positions) && !identical(schema_spec__name_type(self@name), "unnamed")) {
            return("`positions` requires `keys$type = 'unnamed'`.")
        }

        if (identical(schema_spec__name_type(self@name), "unnamed") && (length(self@exact) || length(self@patterns))) {
            return("`keys$type = 'unnamed'` only allows `positions` and `rest` constraints.")
        }
    }
)

SchemaNodeRef <- S7::new_class(
    "SchemaNodeRef",
    parent = SchemaNode,
    properties = list(
        ref = schema_utils__prop_ref(null.ok = FALSE)
    )
)

SchemaNodeNary <- S7::new_class(
    "SchemaNodeNary",
    parent = SchemaNode,
    abstract = TRUE
)

SchemaNodeNaryCmpt <- S7::new_class(
    "SchemaNodeNaryCmpt",
    parent = SchemaNodeNary,
    properties = list(
        branches = schema_utils__prop_list("SchemaNode", names = "unnamed", min.len = 1L, default = list())
    ),
    abstract = TRUE
)

SchemaNodeAllCmpt <- S7::new_class(
    "SchemaNodeAllCmpt",
    parent = SchemaNodeNaryCmpt
)

SchemaNodeAnyCmpt <- S7::new_class(
    "SchemaNodeAnyCmpt",
    parent = SchemaNodeNaryCmpt
)

SchemaNodeOneCmpt <- S7::new_class(
    "SchemaNodeOneCmpt",
    parent = SchemaNodeNaryCmpt
)

SchemaNodeNot <- S7::new_class(
    "SchemaNodeNot",
    parent = SchemaNode,
    abstract = TRUE
)

SchemaNodeNotCmpt <- S7::new_class(
    "SchemaNodeNotCmpt",
    parent = SchemaNodeNot,
    properties = list(
        branch = S7::new_property(SchemaNode)
    )
)
# }}}

# schame_spec_node {{{
schema_spec__error <- function(path, message) {
    stop(sprintf("Path at '%s' is invalid:\n- %s", path, message), call. = FALSE)
}

schema_spec__assert <- function(path, what, check) {
    if (!isTRUE(check)) {
        schema_spec__error(path, sprintf("%s: %s", what, check))
    }
}

schema_spec__assert_list <- function(path, what, x, names = "unique", ...) {
    schema_spec__assert(path, what, checkmate::check_list(x, names = names, ...))
}

schema_spec__assert_names <- function(path, what, x, ...) {
    schema_spec__assert(path, what, checkmate::check_names(names(x), ...))
}

schema_spec__rule <- function(x, path) {
    schema_spec__assert_list(path, "'check' rule", x)
    schema_spec__assert_names(path, "'check' rule", x, must.include = "kind")

    args <- if (any(names(x) != "kind")) {
        unclass(x[names(x) != "kind"])
    } else {
        list()
    }

    SchemaRuleCheck(
        kind = x$kind,
        args = args
    )
}

schema_spec__name_rule <- function(x, path) {
    schema_spec__assert_list(path, "'keys' rule", x)
    SchemaRuleNames(args = unclass(x))
}

schema_spec__node_check <- function(x, path, defs, root = FALSE) {
    schema_spec__assert_list(path, "'check'", x)
    schema_spec__assert_names(
        path,
        "'check'",
        x,
        must.include = "check",
        subset.of = c("check", "keys", "fields", "groups", "patterns", "positions", "rest", "description")
    )

    parts <- list(desc = x$description)
    parts$value <- schema_spec__rule(x$check, paste0(path, "$check"))
    if (!is.null(x$keys)) {
        parts$name <- schema_spec__name_rule(x$keys, paste0(path, "$keys"))
    }

    if (!schema_spec__kind_is_container(parts$value@kind)) {
        if (!is.null(x$fields)) {
            schema_spec__error(path, "'fields' is only allowed on container check nodes.")
        }
        if (!is.null(x$groups)) {
            schema_spec__error(path, "'groups' is only allowed on container 'check' nodes.")
        }
        if (!is.null(x$patterns)) {
            schema_spec__error(path, "'patterns' is only allowed on container 'check' nodes.")
        }
        if (!is.null(x$positions)) {
            schema_spec__error(path, "'positions' is only allowed on container 'check' nodes.")
        }
        if (!is.null(x$rest)) {
            schema_spec__error(path, "'rest' is only allowed on container 'check' nodes.")
        }

        return(do.call(SchemaNodeLeaf, parts))
    }

    parts$exact <- c(
        schema_spec__binding_fields(x$fields, paste0(path, "$fields"), defs),
        schema_spec__binding_groups(x$groups, paste0(path, "$groups"), defs)
    )
    parts$patterns <- schema_spec__binding_patterns(x$patterns, paste0(path, "$patterns"), defs)
    parts$positions <- schema_spec__positions(x$positions, paste0(path, "$positions"), defs)

    if (!is.null(x$rest)) {
        parts$rest <- schema_spec__node(x$rest, paste0(path, "$rest"), defs)
    }

    do.call(SchemaNodeContainerCmpt, parts)
}

schema_spec__has_operator <- function(x) {
    any(names(x) %in% SCHEMA_SPEC_OPERATORS)
}

schema_spec__operator <- function(x, path) {
    op <- names(x)
    op <- op[op %in% SCHEMA_SPEC_OPERATORS]

    if (length(op) == 0L) {
        schema_spec__error(
            path,
            sprintf(
                "primary operator: Must be element of set {%s}, but is missing.",
                paste0("'", SCHEMA_SPEC_OPERATORS, "'", collapse = ", ")
            )
        )
    } else if (length(op) > 1L) {
        schema_spec__error(
            path,
            sprintf(
                "primary operator: Must be element of set {%s}, but multiple found: {%s}.",
                paste0("'", SCHEMA_SPEC_OPERATORS, "'", collapse = ", "),
                paste0("'", op, "'", collapse = ", ")
            )
        )
    }

    op
}

schema_spec__binding_fields <- function(fields, path, defs) {
    if (is.null(fields)) {
        return(NULL)
    }

    schema_spec__assert_list(path, "'fields'", fields, types = "list")

    lapply(names(fields), function(name) {
        SchemaBindingExactCmpt(
            keys = name,
            target = schema_spec__node(
                x = fields[[name]],
                path = paste0(path, "$", name),
                defs = defs,
                root = FALSE
            )
        )
    })
}

schema_spec__binding_groups <- function(groups, path, defs) {
    if (is.null(groups)) {
        return(NULL)
    }

    schema_spec__assert_list(path, "'groups'", groups, types = "list", names = "unnamed")

    lapply(seq_along(groups), function(i) {
        group <- groups[[i]]
        loc <- paste0(path, "[", i, "]")

        schema_spec__assert_list(loc, "group item", group)

        schema_spec__assert_names(
            loc,
            "group item",
            group,
            type = "unique",
            must.include = "names",
            subset.of = c("names", setdiff(SCHEMA_SPEC_KEYWORDS, c("version", "$defs")))
        )

        target <- group[names(group) != "names"]
        SchemaBindingExactCmpt(
            keys = group$names,
            target = schema_spec__node(
                x = target,
                path = loc,
                defs = defs,
                root = FALSE
            )
        )
    })
}

schema_spec__binding_patterns <- function(patterns, path, defs) {
    if (is.null(patterns)) {
        return(NULL)
    }

    schema_spec__assert_list(path, "'patterns'", patterns, types = "list", names = "unique")

    lapply(names(patterns), function(pattern) {
        SchemaBindingPatternCmpt(
            pattern = pattern,
            target = schema_spec__node(
                x = patterns[[pattern]],
                path = paste0(path, "$", pattern),
                defs = defs,
                root = FALSE
            )
        )
    })
}

schema_spec__positions <- function(positions, path, defs) {
    if (is.null(positions)) {
        return(NULL)
    }

    schema_spec__assert_list(path, "'positions'", positions, types = "list", names = "unnamed")

    lapply(seq_along(positions), function(i) {
        schema_spec__node(
            x = positions[[i]],
            path = paste0(path, "[", i, "]"),
            defs = defs,
            root = FALSE
        )
    })
}

schema_spec__node_ref <- function(x, path, defs, root = FALSE) {
    schema_spec__assert_list(path, "$`$ref`", x, types = "character")
    schema_spec__assert_names(path, "$`$ref`", x, must.include = "$ref", subset.of = c("$ref", "description"))

    checkmate::assert_character(defs, any.missing = FALSE, min.chars = 1L, names = "unnamed", null.ok = TRUE)
    if (!is.null(defs)) {
        def_name <- sub("^#/\\$defs/", "", x$`$ref`)
        schema_spec__assert(
            path,
            "'$ref' target",
            checkmate::check_choice(def_name, defs)
        )
    }

    SchemaNodeRef(ref = x$`$ref`, desc = x$description)
}

schema_spec__node_branch <- function(x, path, defs, operator) {
    schema_spec__assert_list(path, "branch node", x)

    if (schema_spec__has_operator(x)) {
        schema_spec__node(x, path = path, defs = defs, root = FALSE)
    } else if ("kind" %in% names(x)) {
        if (any(SCHEMA_SPEC_KEYWORDS %in% names(x))) {
            schema_spec__error(
                path,
                sprintf(
                    "- @branches in shorthand check node format must not contain reserved node-level keys or any primary operator, but {%s} %s found.",
                    paste0("'", SCHEMA_SPEC_KEYWORDS[SCHEMA_SPEC_KEYWORDS %in% names(x)], "'", collapse = ","),
                    if (sum(SCHEMA_SPEC_KEYWORDS %in% names(x)) > 1L) "were" else "was"
                )
            )
        }

        schema_spec__node_check(list(check = x), path = path, defs = defs, root = FALSE)
    } else {
        schema_spec__error(
            path,
            "branch node must be a valid schema node with a primary operator or a shorthand 'check' rule"
        )
    }
}

schema_spec__node_nary <- function(x, path, defs, operator, constructor, root = FALSE) {
    schema_spec__assert_list(path, sprintf("'%s' node", operator), x, types = c("list", "character"))
    schema_spec__assert_names(
        path,
        sprintf("'%s' node", operator),
        x,
        type = "unique",
        must.include = operator,
        subset.of = c("description", operator)
    )
    schema_spec__assert_names(
        sprintf("%s$%s", path, operator),
        sprintf("'%s' node", operator),
        x[[operator]],
        type = "unnamed"
    )

    do.call(
        constructor,
        list(
            branches = lapply(seq_along(x[[operator]]), function(i) {
                schema_spec__node_branch(
                    x[[operator]][[i]],
                    path = sprintf("%s$%s[%d]", path, operator, i),
                    defs = defs,
                    operator = operator
                )
            }),
            desc = x$description
        )
    )
}

schema_spec__node_not <- function(x, path, defs, root = FALSE) {
    schema_spec__assert_list(path, "'not' node", x, types = c("list", "character"))
    schema_spec__assert_names(
        path,
        sprintf("'%s' node", "not"),
        x,
        type = "unique",
        must.include = "not",
        subset.of = c("description", "not")
    )

    do.call(
        SchemaNodeNotCmpt,
        list(
            branch = schema_spec__node_branch(
                x$not,
                paste0(path, "$not"),
                defs = defs,
                operator = "not"
            ),
            desc = x$description
        )
    )
}

schema_spec__node <- function(x, path = "$", defs = character(), root = FALSE) {
    if (S7::S7_inherits(x, SchemaNode)) {
        return(x)
    }

    schema_spec__assert_list(path, "schema node", x)
    schema_spec__assert_names(path, "schema node", x)
    if (!root && !is.null(x$`$defs`)) {
        schema_spec__error(path, "`$defs` is only allowed at the root schema document.")
    }

    switch(
        schema_spec__operator(x, path),
        check = schema_spec__node_check(x, path, defs = defs, root = root),
        `$ref` = schema_spec__node_ref(x, path, defs = defs, root = root),
        all = schema_spec__node_nary(
            x,
            path,
            defs = defs,
            operator = "all",
            constructor = SchemaNodeAllCmpt,
            root = root
        ),
        any = schema_spec__node_nary(
            x,
            path,
            defs = defs,
            operator = "any",
            constructor = SchemaNodeAnyCmpt,
            root = root
        ),
        one = schema_spec__node_nary(
            x,
            path,
            defs = defs,
            operator = "one",
            constructor = SchemaNodeOneCmpt,
            root = root
        ),
        not = schema_spec__node_not(x, path, defs = defs, root = root),
        schema_spec__error(path, "unsupported primary operator.")
    )
}
# }}}

# as.list.SchemaSpec {{{
S7::method(as.list, SchemaBindingExact) <- function(x, ...) {
    out <- list()
    if (length(x@keys) == 1L) {
        out$fields <- list()
        out$fields[[x@keys]] <- as.list(x@target)
    } else {
        out$groups <- c(list(names = x@keys), as.list(x@target))
    }
    out
}

S7::method(as.list, SchemaBindingPattern) <- function(x, ...) {
    out <- list(patterns = list())
    out$patterns[[x@pattern]] <- as.list(x@target)
    out
}

S7::method(as.list, SchemaRuleCheck) <- function(x, ...) {
    schema_utils__as_list_rule(x)
}

S7::method(as.list, SchemaRuleNames) <- function(x, ...) {
    schema_utils__as_list_rule_names(x)
}

S7::method(as.list, SchemaNodeLeaf) <- function(x, ...) {
    out <- list(check = as.list(x@value))
    keys <- schema_utils__keys_as_list(x@name)
    if (!is.null(keys)) {
        out$keys <- keys
    }
    schema_utils__as_list_add_desc(out, x)
}

S7::method(as.list, SchemaNodeContainerCmpt) <- function(x, ...) {
    out <- list(check = as.list(x@value))
    keys <- schema_utils__keys_as_list(x@name)
    if (!is.null(keys)) {
        out$keys <- keys
    }

    bindings <- lapply(x@exact, as.list)
    fields <- unlist(lapply(bindings, "[[", "fields"), recursive = FALSE)
    groups <- lapply(bindings, "[[", "groups")
    groups <- groups[!vapply(groups, is.null, logical(1L))]
    if (length(fields)) {
        out$fields <- fields
    }
    if (length(groups)) {
        out$groups <- groups
    }
    patterns <- unlist(lapply(lapply(x@patterns, as.list), "[[", "patterns"), recursive = FALSE)
    if (length(patterns)) {
        out$patterns <- patterns
    }
    if (length(x@positions)) {
        out$positions <- lapply(x@positions, as.list)
    }
    if (!is.null(x@rest)) {
        out$rest <- as.list(x@rest)
    }

    schema_utils__as_list_add_desc(out, x)
}

S7::method(as.list, SchemaNodeRef) <- function(x, ...) {
    out <- list()
    out[["$ref"]] <- x@ref
    schema_utils__as_list_add_desc(out, x)
}

S7::method(as.list, SchemaNodeAllCmpt) <- function(x, ...) {
    schema_utils__as_list_nary(x, "all")
}

S7::method(as.list, SchemaNodeAnyCmpt) <- function(x, ...) {
    schema_utils__as_list_nary(x, "any")
}

S7::method(as.list, SchemaNodeOneCmpt) <- function(x, ...) {
    schema_utils__as_list_nary(x, "one")
}

S7::method(as.list, SchemaNodeNotCmpt) <- function(x, ...) {
    out <- list(not = as.list(x@branch))
    schema_utils__as_list_add_desc(out, x)
}
# }}}

# schema_utils__as_json.SchemaSpec {{{
S7::method(schema_utils__as_json, SchemaSpec) <- function(x, pretty = TRUE, auto_unbox = TRUE) {
    schema_utils__as_json_impl(x, pretty = pretty, auto_unbox = auto_unbox)
}
# }}}

S7::method(print, SchemaSpec) <- function(x, ..., pretty = TRUE, auto_unbox = TRUE) {
    schema_utils__cat_json(x, ..., pretty = pretty, auto_unbox = auto_unbox)
}

# vim: fdm=marker :
