#' @include schema-utils.R
#' @include schema-doc.R

# SchemaFlat {{{
schema_flat__node_is_flat <- function(x) {
    S7::S7_inherits(x, SchemaNodeLeaf) ||
        S7::S7_inherits(x, SchemaNodeContainerFlat) ||
        S7::S7_inherits(x, SchemaNodeNaryFlat) ||
        S7::S7_inherits(x, SchemaNodeNotFlat)
}

schema_flat__binding_name <- function(x) {
    x@keys[[1L]]
}

schema_flat__binding_names <- function(x) {
    vapply(x, schema_flat__binding_name, character(1L))
}

SchemaBindingFlat <- S7::new_class(
    "SchemaBindingFlat",
    parent = SchemaBinding,
    validator = function(self) {
        if (length(self@keys) != 1L) {
            return("@keys requires exactly one key.")
        }

        if (!schema_flat__node_is_flat(self@target)) {
            return("@target must be a flat schema node.")
        }
    }
)

SchemaNodeContainerFlat <- S7::new_class(
    "SchemaNodeContainerFlat",
    parent = SchemaNodeContainer,
    properties = list(
        bindings = schema_utils__prop_list(
            "SchemaBindingFlat",
            names = "unnamed",
            default = list()
        ),
        dynamic = S7::new_property(
            NULL | SchemaNode,
            default = NULL
        )
    ),
    validator = function(self) {
        if (!schema_spec__kind_is_container(self@value@kind)) {
            return(sprintf(
                "@value requires a container kind; got `%s`. Allowed container kinds are: %s.",
                self@value@kind,
                paste0("'", SCHEMA_SPEC_KINDS_CONTAINER, "'", collapse = ", ")
            ))
        }

        if (!is.null(self@dynamic) && !schema_flat__node_is_flat(self@dynamic)) {
            return("@dynamic must be a flat schema node.")
        }

        if (length(self@bindings) > 0L) {
            keys <- vapply(self@bindings, function(x) x@keys, character(1L))
            msg <- schema_utils__checkmate_result(checkmate::check_character(keys, unique = TRUE), label = "@bindings")
            if (!is.null(msg)) {
                return(sprintf("%s ('%s')", msg, keys[duplicated(keys)][[1L]]))
            }
        }
    }
)

SchemaNodeNaryFlat <- S7::new_class(
    "SchemaNodeNaryFlat",
    parent = SchemaNodeNary,
    properties = list(
        branches = schema_utils__prop_list(
            "SchemaNode",
            names = "unnamed",
            min.len = 1L,
            default = list()
        )
    ),
    validator = function(self) {
        bad <- !vapply(self@branches, schema_flat__node_is_flat, logical(1L))
        if (any(bad)) {
            return("@branches must all be flat schema nodes.")
        }
    },
    abstract = TRUE
)

SchemaNodeAllFlat <- S7::new_class("SchemaNodeAllFlat", parent = SchemaNodeNaryFlat)
SchemaNodeAnyFlat <- S7::new_class("SchemaNodeAnyFlat", parent = SchemaNodeNaryFlat)
SchemaNodeOneFlat <- S7::new_class("SchemaNodeOneFlat", parent = SchemaNodeNaryFlat)

SchemaNodeNotFlat <- S7::new_class(
    "SchemaNodeNotFlat",
    parent = SchemaNodeNot,
    properties = list(
        branch = S7::new_property(
            SchemaNode,
            validator = function(value) {
                if (!schema_flat__node_is_flat(value)) {
                    return("@branch must be a flat schema node.")
                }
            }
        )
    )
)

SchemaFlat <- S7::new_class(
    "SchemaFlat",
    parent = SchemaSpec,
    properties = list(
        path = schema_utils__prop_string(null.ok = TRUE, default = NULL),
        version = schema_utils__prop_string(null.ok = TRUE),
        root = S7::new_property(
            SchemaNode,
            validator = function(value) {
                if (!schema_flat__node_is_flat(value)) {
                    return("@root must be a flat schema node.")
                }
            }
        )
    )
)
# }}}

# as.list.Schema {{{
S7::method(as.list, SchemaNodeContainerFlat) <- function(x, ...) {
    out <- list(check = as.list(x@value))
    keys <- schema_utils__keys_as_list(x@name)
    if (!is.null(keys)) {
        out$keys <- keys
    }
    if (length(x@bindings) || !is.null(x@dynamic)) {
        fields <- stats::setNames(
            lapply(x@bindings, function(binding) as.list(binding@target)),
            vapply(x@bindings, function(binding) binding@keys, character(1L))
        )
        if (!is.null(x@dynamic)) {
            fields[["*"]] <- as.list(x@dynamic)
        }
        out$fields <- fields
    }
    schema_utils__as_list_add_desc(out, x)
}

S7::method(as.list, SchemaNodeAllFlat) <- function(x, ...) {
    schema_utils__as_list_nary(x, "all")
}

S7::method(as.list, SchemaNodeAnyFlat) <- function(x, ...) {
    schema_utils__as_list_nary(x, "any")
}

S7::method(as.list, SchemaNodeOneFlat) <- function(x, ...) {
    schema_utils__as_list_nary(x, "one")
}

S7::method(as.list, SchemaNodeNotFlat) <- function(x, ...) {
    schema_utils__as_list_add_desc(list(not = as.list(x@branch)), x)
}

S7::method(as.list, SchemaFlat) <- function(x, ...) {
    # Top-level serialization contract for SchemaFlat:
    # 1. `version` first when present
    # 2. serialized root schema entries last
    # 3. `path` is compile metadata and is intentionally excluded
    # Root node serialization itself follows the shared contract that
    # `description` appears before all operator-specific entries.
    out <- list()
    if (!is.null(x@version)) {
        out$version <- x@version
    }
    c(out, as.list(x@root))
}
# }}}

# schema_flat__compile {{{
schema_flat__rule_check <- function(x) {
    if (!length(x@args)) {
        return(SchemaRuleCheck(kind = x@kind))
    }

    SchemaRuleCheck(kind = x@kind, args = x@args)
}

schema_flat__rule_names <- function(x) {
    if (is.null(x)) {
        return(NULL)
    }
    SchemaRuleNames(args = x@args)
}

schema_flat__ref_name <- function(ref) {
    sub("^#/\\$defs/", "", ref)
}

schema_flat__context <- function(defs = list()) {
    ctx <- new.env(parent = emptyenv())
    ctx$defs <- defs
    ctx$cache <- list()
    ctx$stack <- character()
    ctx
}

schema_flat__overlay_desc <- S7::new_generic(
    "schema_flat__overlay_desc",
    "x",
    function(x, desc) S7::S7_dispatch()
)

S7::method(schema_flat__overlay_desc, SchemaNodeLeaf) <- function(x, desc) {
    if (is.null(desc)) {
        return(x)
    }

    SchemaNodeLeaf(value = x@value, name = x@name, desc = desc)
}

S7::method(schema_flat__overlay_desc, SchemaNodeContainerFlat) <- function(x, desc) {
    if (is.null(desc)) {
        return(x)
    }

    SchemaNodeContainerFlat(
        value = x@value,
        name = x@name,
        bindings = x@bindings,
        dynamic = x@dynamic,
        desc = desc
    )
}

S7::method(schema_flat__overlay_desc, SchemaNodeAllFlat) <- function(x, desc) {
    if (is.null(desc)) {
        return(x)
    }

    SchemaNodeAllFlat(branches = x@branches, desc = desc)
}

S7::method(schema_flat__overlay_desc, SchemaNodeAnyFlat) <- function(x, desc) {
    if (is.null(desc)) {
        return(x)
    }

    SchemaNodeAnyFlat(branches = x@branches, desc = desc)
}

S7::method(schema_flat__overlay_desc, SchemaNodeOneFlat) <- function(x, desc) {
    if (is.null(desc)) {
        return(x)
    }

    SchemaNodeOneFlat(branches = x@branches, desc = desc)
}

S7::method(schema_flat__overlay_desc, SchemaNodeNotFlat) <- function(x, desc) {
    if (is.null(desc)) {
        return(x)
    }

    SchemaNodeNotFlat(branch = x@branch, desc = desc)
}

S7::method(schema_flat__overlay_desc, SchemaNode) <- function(x, desc) {
    if (is.null(desc)) {
        return(x)
    }

    stop("unsupported compiled schema node.", call. = FALSE)
}

schema_flat__def <- function(name, ctx) {
    if (is.null(ctx$defs[[name]])) {
        stop(sprintf("`$ref` target `#/$defs/%s` is not available during compilation.", name), call. = FALSE)
    }

    if (name %in% ctx$stack) {
        stop(
            sprintf(
                "circular `$ref` detected while compiling: %s.",
                paste(c(ctx$stack, name), collapse = " -> ")
            ),
            call. = FALSE
        )
    }

    if (!is.null(ctx$cache[[name]])) {
        return(ctx$cache[[name]])
    }

    ctx$stack <- c(ctx$stack, name)
    on.exit(
        {
            ctx$stack <- utils::head(ctx$stack, -1L)
        },
        add = TRUE
    )

    compiled <- schema_flat__node(ctx$defs[[name]], ctx)
    ctx$cache[[name]] <- compiled
    compiled
}

schema_flat__ref <- function(x, ctx) {
    schema_flat__overlay_desc(schema_flat__def(schema_flat__ref_name(x@ref), ctx), x@desc)
}

S7::method(schema_utils__convert, SchemaBindingCmpt) <- function(from, to, ...) {
    if (!identical(to, SchemaBindingFlat)) {
        stop("`SchemaBindingCmpt` can only be converted to `SchemaBindingFlat`.", call. = FALSE)
    }
    if (length(from@keys) != 1L) {
        stop("`SchemaBindingCmpt` must contain exactly one key to convert to `SchemaBindingFlat`.", call. = FALSE)
    }

    SchemaBindingFlat(keys = from@keys, target = from@target)
}

schema_flat__binding <- function(binding, ctx) {
    target <- schema_flat__node(binding@target, ctx)
    lapply(binding@keys, function(key) {
        schema_utils__convert(SchemaBindingCmpt(keys = key, target = target), SchemaBindingFlat)
    })
}

schema_flat__bindings <- function(bindings, ctx) {
    compiled <- unlist(lapply(bindings, schema_flat__binding, ctx = ctx), recursive = FALSE)
    if (length(compiled)) {
        keys <- schema_flat__binding_names(compiled)
        dup_keys <- unique(keys[duplicated(keys)])
        if (length(dup_keys)) {
            stop(sprintf("duplicate compiled field key(s): %s.", paste(dup_keys, collapse = ", ")), call. = FALSE)
        }
    }

    compiled
}

schema_flat__branches <- function(branches, ctx) {
    lapply(branches, schema_flat__node, ctx = ctx)
}

schema_flat__doc <- function(x) {
    ctx <- schema_flat__context(x@defs)

    SchemaFlat(
        path = x@path,
        version = x@version,
        root = schema_flat__node(x@root, ctx)
    )
}

schema_flat__node <- S7::new_generic(
    "schema_flat__node",
    "x",
    function(x, ctx) S7::S7_dispatch()
)

S7::method(schema_flat__node, SchemaNodeLeaf) <- function(x, ctx) {
    SchemaNodeLeaf(
        value = schema_flat__rule_check(x@value),
        name = schema_flat__rule_names(x@name),
        desc = x@desc
    )
}

S7::method(schema_flat__node, SchemaNodeContainerCmpt) <- function(x, ctx) {
    bindings <- schema_flat__bindings(x@bindings, ctx)
    dynamic <- if (is.null(x@dynamic)) NULL else schema_flat__node(x@dynamic, ctx)

    SchemaNodeContainerFlat(
        value = schema_flat__rule_check(x@value),
        name = schema_flat__rule_names(x@name),
        bindings = bindings,
        dynamic = dynamic,
        desc = x@desc
    )
}

S7::method(schema_flat__node, SchemaNodeRef) <- function(x, ctx) {
    schema_flat__ref(x, ctx)
}

S7::method(schema_flat__node, SchemaNodeAllCmpt) <- function(x, ctx) {
    SchemaNodeAllFlat(branches = schema_flat__branches(x@branches, ctx), desc = x@desc)
}

S7::method(schema_flat__node, SchemaNodeAnyCmpt) <- function(x, ctx) {
    SchemaNodeAnyFlat(branches = schema_flat__branches(x@branches, ctx), desc = x@desc)
}

S7::method(schema_flat__node, SchemaNodeOneCmpt) <- function(x, ctx) {
    SchemaNodeOneFlat(branches = schema_flat__branches(x@branches, ctx), desc = x@desc)
}

S7::method(schema_flat__node, SchemaNodeNotCmpt) <- function(x, ctx) {
    SchemaNodeNotFlat(branch = schema_flat__node(x@branch, ctx), desc = x@desc)
}

S7::method(schema_flat__node, SchemaNode) <- function(x, ctx) {
    stop("unsupported authoring schema node.", call. = FALSE)
}

S7::method(schema_flat__node, S7::class_any) <- function(x, ctx) {
    stop("unsupported authoring schema node.", call. = FALSE)
}

schema_flat__compile <- S7::new_generic("schema_flat__compile", "x", function(x) S7::S7_dispatch())

S7::method(schema_flat__compile, SchemaFlat) <- function(x) {
    x
}

S7::method(schema_flat__compile, SchemaNodeLeaf) <- function(x) {
    SchemaFlat(root = x)
}

S7::method(schema_flat__compile, SchemaNodeContainerFlat) <- function(x) {
    SchemaFlat(root = x)
}

S7::method(schema_flat__compile, SchemaNodeAllFlat) <- function(x) {
    SchemaFlat(root = x)
}

S7::method(schema_flat__compile, SchemaNodeAnyFlat) <- function(x) {
    SchemaFlat(root = x)
}

S7::method(schema_flat__compile, SchemaNodeOneFlat) <- function(x) {
    SchemaFlat(root = x)
}

S7::method(schema_flat__compile, SchemaNodeNotFlat) <- function(x) {
    SchemaFlat(root = x)
}

S7::method(schema_flat__compile, SchemaDoc) <- function(x) {
    schema_flat__doc(x)
}

S7::method(schema_flat__compile, S7::class_any) <- function(x) {
    stop(
        paste(
            "`schema_flat__compile()` only accepts `SchemaDoc`, flat runtime `SchemaNode`, or `SchemaFlat`.",
            "Use `schema_flat__node()` internally for authoring `SchemaNode` values."
        ),
        call. = FALSE
    )
}
# }}}

# vim: fdm=marker :
