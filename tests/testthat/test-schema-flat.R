test_that("SchemaBindingExactFlat", {
    expect_error(
        SchemaBindingExactFlat(
            keys = c("a", "b"),
            target = SchemaNodeRef(ref = "#/$defs/value")
        ),
        "one key"
    )

    expect_error(
        SchemaBindingExactFlat(
            keys = "a",
            target = SchemaNodeRef(ref = "#/$defs/value")
        ),
        "flat schema node"
    )

    expect_s7_class(
        SchemaBindingExactFlat(
            keys = "a",
            target = SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string"))
        ),
        SchemaBindingExactFlat
    )
})

test_that("SchemaNodeContainerFlat", {
    expect_error(
        SchemaNodeContainerFlat(
            value = SchemaRuleCheck(kind = "string"),
            exact = NULL
        ),
        "container kind"
    )
    expect_error(
        SchemaNodeContainerFlat(
            value = SchemaRuleCheck(kind = "list"),
            rest = SchemaNodeContainerCmpt(value = SchemaRuleCheck(kind = "list"))
        ),
        "flat schema"
    )

    expect_error(
        SchemaNodeContainerFlat(
            value = SchemaRuleCheck(kind = "list"),
            exact = SchemaBindingExactFlat(
                keys = "a",
                target = SchemaNodeRef(ref = "#/$defs/value")
            )
        ),
        "flat schema node"
    )

    expect_s7_class(
        SchemaNodeContainerFlat(
            value = SchemaRuleCheck(kind = "list", args = list()),
            name = SchemaRuleNames(args = list(type = "named")),
            exact = list(SchemaBindingExactFlat(
                "a",
                SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string"))
            )),
            rest = SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string", args = list(null.ok = TRUE)))
        ),
        SchemaNodeContainerFlat
    )
})

test_that("schema_flat__compile()", {
    doc <- schema_doc(
        list(
            version = "1.0.0",
            `$defs` = list(
                text = list(
                    check = list(kind = "string", min.chars = 1L),
                    keys = list(type = "named")
                )
            ),
            `$ref` = "#/$defs/text"
        ),
        path = "inst/extdata/schema-doc.json"
    )

    flat <- schema_flat__compile(doc)

    expect_true(S7::S7_inherits(flat, SchemaFlat))
    expect_equal(flat@version, "1.0.0")
    expect_equal(flat@path, "inst/extdata/schema-doc.json")
    expect_true(S7::S7_inherits(flat@root, SchemaNodeLeaf))
    expect_equal(flat@root@value, SchemaRuleCheck(kind = "string", args = list(min.chars = 1L)))
    expect_equal(flat@root@name, SchemaRuleNames(args = list(type = "named")))

    doc <- schema_doc(list(
        `$defs` = list(text = list(check = list(kind = "string"))),
        check = list(kind = "data_frame"),
        keys = list(type = "unique", must.include = c("id", "name")),
        groups = list(
            list(names = c("name", "label"), `$ref` = "#/$defs/text")
        ),
        fields = list(
            id = list(check = list(kind = "int"))
        ),
        patterns = list(
            "^meta_" = list(`$ref` = "#/$defs/text")
        ),
        rest = list(check = list(kind = "string", null.ok = TRUE))
    ))

    flat <- schema_flat__compile(doc)
    root <- flat@root

    expect_true(S7::S7_inherits(root, SchemaNodeContainerFlat))
    expect_equal(root@value, SchemaRuleCheck(kind = "data_frame"))
    expect_equal(root@name, SchemaRuleNames(args = list(type = "unique", must.include = c("id", "name"))))
    expect_equal(
        vapply(root@exact, function(binding) binding@keys, character(1L)),
        c("id", "name", "label")
    )
    expect_equal(
        root@exact[[1L]],
        SchemaBindingExactFlat("id", SchemaNodeLeaf(value = SchemaRuleCheck(kind = "int")))
    )
    expect_equal(
        root@exact[[2L]],
        SchemaBindingExactFlat("name", SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string")))
    )
    expect_equal(
        root@exact[[3L]],
        SchemaBindingExactFlat("label", SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string")))
    )
    expect_true(S7::S7_inherits(root@rest, SchemaNodeLeaf))
    expect_equal(root@rest@value, SchemaRuleCheck(kind = "string", args = list(null.ok = TRUE)))
    expect_length(root@patterns, 1L)
    expect_equal(root@patterns[[1L]], SchemaBindingPatternFlat("^meta_", SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string"))))

    doc <- schema_doc(list(
        `$defs` = list(
            text = list(
                description = "def text",
                check = list(kind = "string"),
                keys = list(type = "named")
            )
        ),
        any = list(
            list(description = "site text", `$ref` = "#/$defs/text"),
            list(kind = "string")
        )
    ))

    flat <- schema_flat__compile(doc)
    expect_true(S7::S7_inherits(flat@root, SchemaNodeAnyFlat))
    expect_equal(flat@root@branches[[1L]]@desc, "site text")
    expect_equal(flat@root@branches[[1L]]@name, SchemaRuleNames(args = list(type = "named")))
    expect_equal(flat@root@branches[[2L]]@value, SchemaRuleCheck(kind = "string"))

    circular_doc <- schema_doc(list(
        `$defs` = list(
            a = list(`$ref` = "#/$defs/b"),
            b = list(`$ref` = "#/$defs/a")
        ),
        `$ref` = "#/$defs/a"
    ))

    expect_error(schema_flat__compile(circular_doc), "circular `\\$ref`")

    bad_runtime_ref <- SchemaNodeRef(ref = "#/$defs/missing")
    bad_ctx <- schema_flat__context()
    expect_error(schema_flat__node(bad_runtime_ref, bad_ctx), "is not available during compilation")

    runtime <- SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string"))
    flat <- SchemaFlat(root = runtime, version = "1.0.0")
    authoring <- schema_doc(list(check = list(kind = "list"), fields = list(id = list(check = list(kind = "string")))))

    expect_identical(schema_flat__compile(flat), flat)

    wrapped <- schema_flat__compile(runtime)
    expect_true(S7::S7_inherits(wrapped, SchemaFlat))
    expect_equal(wrapped@root, runtime)
    expect_null(wrapped@version)
    expect_null(wrapped@path)

    expect_error(
        schema_flat__compile(authoring@root),
        "only accepts `SchemaDoc`, flat runtime `SchemaNode`, or `SchemaFlat`"
    )
    expect_equal(schema_flat__node(runtime, schema_flat__context()), runtime)

    doc <- schema_doc(list(
        `$defs` = list(text = list(check = list(kind = "string"))),
        any = list(
            list(description = "first text", `$ref` = "#/$defs/text"),
            list(description = "second text", `$ref` = "#/$defs/text")
        )
    ))

    ctx <- schema_flat__context(doc@defs)
    first <- schema_flat__node(doc@root@branches[[1L]], ctx)
    second <- schema_flat__node(doc@root@branches[[2L]], ctx)
    cached <- schema_flat__def("text", ctx)

    expect_null(cached@desc)
    expect_equal(first@desc, "first text")
    expect_equal(second@desc, "second text")
    expect_equal(first@value, cached@value)
    expect_equal(second@value, cached@value)

    doc <- schema_doc(list(
        `$defs` = list(
            text = list(check = list(kind = "string")),
            numeric = list(check = list(kind = "number"))
        ),
        check = list(kind = "list"),
        keys = list(type = "unnamed"),
        positions = list(
            list(`$ref` = "#/$defs/text"),
            list(check = list(kind = "int"))
        ),
        rest = list(`$ref` = "#/$defs/numeric")
    ))

    flat <- schema_flat__compile(doc)
    expect_true(S7::S7_inherits(flat@root, SchemaNodeContainerFlat))
    expect_length(flat@root@positions, 2L)
    expect_equal(flat@root@positions[[1L]], SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string")))
    expect_equal(flat@root@positions[[2L]], SchemaNodeLeaf(value = SchemaRuleCheck(kind = "int")))
    expect_equal(flat@root@rest, SchemaNodeLeaf(value = SchemaRuleCheck(kind = "number")))
})

test_that("schema_compile() exposes compiled schemas", {
    raw <- list(
        `$defs` = list(text = list(check = list(kind = "string"))),
        check = list(kind = "list"),
        fields = list(
            id = list(check = list(kind = "int", lower = 1L)),
            name = list(`$ref` = "#/$defs/text")
        )
    )
    doc <- schema_doc(raw, path = "schema.json")

    compiled <- schema_compile(raw)
    compiled_doc <- schema_compile(doc)

    expect_s7_class(compiled, SchemaFlat)
    expect_s7_class(compiled_doc, SchemaFlat)
    expect_equal(compiled_doc@path, "schema.json")
    expect_true(isTRUE(schema_validate(compiled, list(id = 1L, name = "alice"), mode = "check", name = "payload")))
    expect_match(
        schema_validate(compiled, list(id = 0L, name = "alice"), mode = "check", name = "payload"),
        "payload\\$id"
    )

    flat <- SchemaFlat(root = SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string")))
    expect_identical(schema_compile(flat), flat)
    expect_s7_class(schema_compile(flat@root), SchemaFlat)

    authoring <- schema_doc(list(check = list(kind = "list"), fields = list(id = list(check = list(kind = "int")))))
    expect_error(
        schema_compile(authoring@root),
        "only accepts `SchemaDoc`, flat runtime `SchemaNode`, or `SchemaFlat`"
    )

    circular <- list(
        `$defs` = list(
            a = list(`$ref` = "#/$defs/b"),
            b = list(`$ref` = "#/$defs/a")
        ),
        `$ref` = "#/$defs/a"
    )
    expect_error(schema_compile(circular), "circular `\\$ref`")
})

test_that("as.list()", {
    # Contract: top-level order for SchemaCompiled is version -> root entries,
    # and root-level description is emitted before operator-specific keys.
    rule_check <- SchemaRuleCheck(kind = "string", args = list(min.chars = 1L))
    rule_names <- SchemaRuleNames(args = list(type = "unique", must.include = c("id", "label")))
    leaf <- SchemaNodeLeaf(value = rule_check, name = rule_names, desc = "leaf")
    int_leaf <- SchemaNodeLeaf(value = SchemaRuleCheck(kind = "int"))
    rest_leaf <- SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string", args = list(null.ok = TRUE)))
    pattern_leaf <- SchemaNodeLeaf(value = SchemaRuleCheck(kind = "flag"))
    position_leaf <- SchemaNodeLeaf(value = SchemaRuleCheck(kind = "number"))
    container <- SchemaNodeContainerFlat(
        value = SchemaRuleCheck(kind = "list"),
        name = rule_names,
        exact = list(
            SchemaBindingExactFlat(
                keys = "id",
                target = int_leaf
            ),
            SchemaBindingExactFlat(
                keys = "label",
                target = leaf
            )
        ),
        patterns = list(SchemaBindingPatternFlat(pattern = "_flag$", target = pattern_leaf)),
        rest = rest_leaf,
        desc = "container"
    )
    array_container <- SchemaNodeContainerFlat(
        value = SchemaRuleCheck(kind = "list"),
        name = SchemaRuleNames(args = list(type = "unnamed")),
        positions = list(leaf, position_leaf),
        rest = rest_leaf,
        desc = "array container"
    )
    all_schema <- SchemaNodeAllFlat(branches = list(leaf, container), desc = "all schema")
    any_schema <- SchemaNodeAnyFlat(branches = list(leaf, container))
    one_schema <- SchemaNodeOneFlat(branches = list(leaf, container), desc = "one schema")
    not_schema <- SchemaNodeNotFlat(branch = leaf, desc = "not schema")
    flat <- SchemaFlat(root = container, version = "1.0.0", path = "inst/schema.json")

    leaf_list <- list(
        description = "leaf",
        check = list(kind = "string", min.chars = 1L),
        keys = list(type = "unique", must.include = c("id", "label"))
    )
    int_leaf_list <- list(check = list(kind = "int"))
    rest_leaf_list <- list(check = list(kind = "string", null.ok = TRUE))
    pattern_leaf_list <- list(check = list(kind = "flag"))
    position_leaf_list <- list(check = list(kind = "number"))
    container_list <- list(
        description = "container",
        check = list(kind = "list"),
        keys = list(type = "unique", must.include = c("id", "label")),
        fields = list(id = int_leaf_list, label = leaf_list),
        patterns = list(`_flag$` = pattern_leaf_list),
        rest = rest_leaf_list
    )
    array_container_list <- list(
        description = "array container",
        check = list(kind = "list"),
        keys = list(type = "unnamed"),
        positions = list(leaf_list, position_leaf_list),
        rest = rest_leaf_list
    )

    expect_equal(as.list(rule_check), list(kind = "string", min.chars = 1L))
    expect_equal(as.list(rule_names), list(type = "unique", must.include = c("id", "label")))
    expect_equal(as.list(leaf), leaf_list)
    expect_equal(as.list(container), container_list)
    expect_equal(as.list(array_container), array_container_list)
    expect_equal(as.list(all_schema), list(description = "all schema", all = list(leaf_list, container_list)))
    expect_equal(as.list(any_schema), list(any = list(leaf_list, container_list)))
    expect_equal(as.list(one_schema), list(description = "one schema", one = list(leaf_list, container_list)))
    expect_equal(as.list(not_schema), list(description = "not schema", not = leaf_list))
    expect_equal(as.list(flat), c(list(version = "1.0.0"), container_list))
    expect_equal(names(as.list(flat)), c("version", "description", "check", "keys", "fields", "patterns", "rest"))
    expect_false("path" %in% names(as.list(flat)))
})

test_that("schema_utils__as_json()", {
    rule_check <- SchemaRuleCheck(kind = "string", args = list(min.chars = 1L))
    rule_names <- SchemaRuleNames(args = list(type = "unique"))
    leaf <- SchemaNodeLeaf(value = rule_check, name = rule_names, desc = "leaf")
    container <- SchemaNodeContainerFlat(
        value = SchemaRuleCheck(kind = "list"),
        name = rule_names,
        exact = list(
            SchemaBindingExactFlat(
                keys = "id",
                target = SchemaNodeLeaf(value = SchemaRuleCheck(kind = "int"))
            )
        ),
        rest = SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string", args = list(null.ok = TRUE))),
        desc = "container"
    )
    all_schema <- SchemaNodeAllFlat(branches = list(leaf, container), desc = "all schema")
    any_schema <- SchemaNodeAnyFlat(branches = list(leaf, container))
    one_schema <- SchemaNodeOneFlat(branches = list(leaf, container))
    not_schema <- SchemaNodeNotFlat(branch = leaf)
    flat <- SchemaFlat(root = container, version = "1.0.0")

    for (obj in list(
        rule_check,
        rule_names,
        leaf,
        container,
        all_schema,
        any_schema,
        one_schema,
        not_schema,
        flat
    )) {
        json <- schema_utils__as_json(obj, pretty = FALSE)
        expect_type(json, "character")
        expect_true(jsonlite::validate(json))
        expect_equal(schema_json__read_json(json), as.list(obj))
    }
})

test_that("base JSON fallback serializes schema-shaped values", {
    expect_equal(schema_utils__to_json_fallback("x", pretty = FALSE), '"x"')
    expect_equal(schema_utils__to_json_fallback("x", pretty = FALSE, auto_unbox = FALSE), '["x"]')
    expect_equal(schema_utils__to_json_fallback(c("x", "y"), pretty = FALSE), '["x","y"]')
    expect_equal(schema_utils__to_json_fallback(c(1L, 2L), pretty = FALSE), "[1,2]")
    expect_equal(schema_utils__to_json_fallback(c(TRUE, FALSE, NA), pretty = FALSE), "[true,false,null]")
    expect_equal(schema_utils__to_json_fallback(NULL, pretty = FALSE), "null")
    expect_equal(schema_utils__to_json_fallback(list(), pretty = FALSE), "[]")
    expect_equal(schema_utils__to_json_fallback(structure(list(), names = character()), pretty = FALSE), "{}")

    value <- list(
        description = "quote \" slash \\ newline\n tab\t",
        check = list(kind = "list"),
        fields = list(
            id = list(check = list(kind = "int")),
            missing = NULL
        ),
        groups = list(list(names = c("name", "label"), check = list(kind = "string")))
    )
    json <- schema_utils__to_json_fallback(value, pretty = FALSE)
    pretty_json <- schema_utils__to_json_fallback(value)

    expect_true(jsonlite::validate(json))
    expect_equal(schema_json__read_json(json), value)
    expect_true(jsonlite::validate(pretty_json))
    expect_gt(length(strsplit(pretty_json, "\n", fixed = TRUE)[[1L]]), 1L)
})

test_that("print()", {
    rule_check <- SchemaRuleCheck(kind = "string", args = list(min.chars = 1L))
    rule_names <- SchemaRuleNames(args = list(type = "unique"))
    leaf <- SchemaNodeLeaf(value = rule_check, name = rule_names, desc = "leaf")
    flat <- SchemaFlat(
        root = SchemaNodeContainerFlat(
            value = SchemaRuleCheck(kind = "list"),
            name = rule_names,
            exact = list(
                SchemaBindingExactFlat(
                    keys = "id",
                    target = SchemaNodeLeaf(value = SchemaRuleCheck(kind = "int"))
                )
            ),
            desc = "container"
        ),
        version = "1.0.0"
    )

    for (obj in list(rule_check, rule_names, leaf, flat)) {
        printed <- NULL
        output <- capture.output(printed <- withVisible(print(obj, pretty = FALSE)))
        expect_equal(output, as.character(schema_utils__as_json(obj, pretty = FALSE)))
        expect_identical(printed$value, obj)
        expect_false(printed$visible)

        pretty_output <- capture.output(print(obj))
        expect_gt(length(pretty_output), 1L)
    }
})
