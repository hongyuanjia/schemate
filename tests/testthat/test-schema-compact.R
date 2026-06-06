test_that("schema_compact() merges inferred array alternatives", {
    schema <- schema_infer(
        list(
            items = list(
                list(id = 1L, name = "alpha"),
                list(id = 2L, description = "beta")
            )
        ),
        keys = "required",
        arrays = "rest"
    )
    compact <- schema_compact(schema, groups = FALSE)

    expect_equal(
        as.list(compact)$fields$items$rest,
        list(
            check = list(kind = "list"),
            keys = list(type = "named", must.include = "id"),
            fields = list(
                id = list(check = list(kind = "int")),
                name = list(check = list(kind = "string")),
                description = list(check = list(kind = "string"))
            )
        )
    )
})

test_that("schema_compact() preserves conflicts as nested any nodes", {
    schema <- schema_infer(
        list(
            items = list(
                list(value = 1L),
                list(value = "one")
            )
        ),
        arrays = "rest"
    )
    compact <- schema_compact(schema, groups = FALSE)

    expect_equal(
        as.list(compact)$fields$items$rest$fields$value,
        list(
            any = list(
                list(check = list(kind = "int")),
                list(check = list(kind = "string"))
            )
        )
    )

    scalar <- schema_doc(list(any = list(list(kind = "int"), list(kind = "string"))))
    expect_equal(as.list(schema_compact(scalar)), as.list(scalar))
})

test_that("schema_compact() merges nested array alternatives", {
    schema <- schema_infer(
        list(
            values = list(
                list(1L, 2L),
                list("x")
            )
        ),
        arrays = "rest"
    )
    compact <- schema_compact(schema)

    expect_equal(
        as.list(compact)$fields$values$rest,
        list(
            check = list(kind = "list"),
            keys = list(type = "unnamed"),
            rest = list(
                any = list(
                    list(check = list(kind = "int")),
                    list(check = list(kind = "string"))
                )
            )
        )
    )
})

test_that("schema_compact() groups identical sibling fields", {
    schema <- schema_doc(list(
        check = list(kind = "list"),
        fields = list(
            a = list(check = list(kind = "string")),
            b = list(check = list(kind = "string")),
            c = list(check = list(kind = "int"))
        )
    ))
    compact <- schema_compact(schema)

    expect_equal(
        as.list(compact),
        list(
            check = list(kind = "list"),
            fields = list(c = list(check = list(kind = "int"))),
            groups = list(list(
                names = c("a", "b"),
                check = list(kind = "string")
            ))
        )
    )

    schema <- schema_doc(list(
        check = list(kind = "list"),
        fields = list(c = list(check = list(kind = "string"))),
        groups = list(list(names = c("a", "b"), check = list(kind = "string")))
    ))
    compact <- schema_compact(schema)

    expect_equal(
        as.list(compact)$groups,
        list(list(
            names = c("c", "a", "b"),
            check = list(kind = "string")
        ))
    )

    schema <- schema_doc(list(
        check = list(kind = "list"),
        fields = list(
            implicit = list(check = list(kind = "string")),
            explicit = list(check = list(kind = "string", null.ok = FALSE))
        )
    ))
    compact <- schema_compact(schema)

    expect_equal(
        as.list(compact)$groups,
        list(list(
            names = c("implicit", "explicit"),
            check = list(kind = "string")
        ))
    )
})

test_that("schema_compact() does not group when disabled or unnamed", {
    schema <- schema_doc(list(
        check = list(kind = "list"),
        fields = list(
            a = list(check = list(kind = "string")),
            b = list(check = list(kind = "string"))
        )
    ))
    compact <- schema_compact(schema, groups = FALSE)

    expect_equal(names(as.list(compact)$fields), c("a", "b"))
    expect_null(as.list(compact)$groups)

    unnamed <- schema_doc(list(
        check = list(kind = "list"),
        keys = list(type = "unnamed"),
        positions = list(
            list(check = list(kind = "string")),
            list(check = list(kind = "string"))
        )
    ))
    compact <- schema_compact(unnamed)

    expect_equal(
        as.list(compact)$positions,
        list(
            list(check = list(kind = "string")),
            list(check = list(kind = "string"))
        )
    )
    expect_null(as.list(compact)$groups)
})

test_that("schema_compact() groups nodes with normalized key rules", {
    schema <- schema_doc(list(
        check = list(kind = "list"),
        fields = list(
            a = list(
                check = list(kind = "list"),
                keys = list(),
                fields = list(value = list(check = list(kind = "string")))
            ),
            b = list(
                check = list(kind = "list"),
                keys = list(type = "named", what = "names"),
                fields = list(value = list(check = list(kind = "string")))
            )
        )
    ))
    compact <- schema_compact(schema)

    expect_length(compact@root@exact, 1L)
    expect_equal(compact@root@exact[[1L]]@keys, c("a", "b"))
    expect_equal(compact@root@exact[[1L]]@target@name, SchemaRuleNames(args = list()))
})

test_that("schema_compact() distinguishes absent and default key rules", {
    schema <- schema_doc(list(
        check = list(kind = "list"),
        fields = list(
            absent = list(check = list(kind = "string")),
            present = list(check = list(kind = "string"), keys = list())
        )
    ))
    compact <- schema_compact(schema)

    expect_length(compact@root@exact, 2L)
    expect_null(as.list(compact)$groups)
    expect_null(compact@root@exact[[1L]]@target@name)
    expect_equal(compact@root@exact[[2L]]@target@name, SchemaRuleNames(args = list()))
})

test_that("schema_compact() keeps descriptions in structural grouping", {
    schema <- schema_doc(list(
        check = list(kind = "list"),
        fields = list(
            a = list(description = "first", check = list(kind = "string")),
            b = list(description = "second", check = list(kind = "string"))
        )
    ))
    compact <- schema_compact(schema)

    expect_length(compact@root@exact, 2L)
    expect_null(as.list(compact)$groups)
})

test_that("schema_compact__same_node() compares S7 slots structurally", {
    string <- SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string"))
    string_default <- SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string", args = list(null.ok = FALSE)))
    ref <- SchemaNodeRef(ref = "#/$defs/value")

    pattern_container <- SchemaNodeContainerCmpt(
        value = SchemaRuleCheck(kind = "list"),
        patterns = list(SchemaBindingPatternCmpt(pattern = "^x", target = string)),
        rest = SchemaNodeNotCmpt(branch = ref)
    )
    pattern_container_default <- SchemaNodeContainerCmpt(
        value = SchemaRuleCheck(kind = "list", args = list(null.ok = FALSE)),
        patterns = list(SchemaBindingPatternCmpt(pattern = "^x", target = string_default)),
        rest = SchemaNodeNotCmpt(branch = ref)
    )
    position_container <- SchemaNodeContainerCmpt(
        value = SchemaRuleCheck(kind = "list"),
        name = SchemaRuleNames(args = list(type = "unnamed")),
        positions = list(string),
        rest = string
    )
    position_container_default <- SchemaNodeContainerCmpt(
        value = SchemaRuleCheck(kind = "list", args = list(null.ok = FALSE)),
        name = SchemaRuleNames(args = list(type = "unnamed", what = "names")),
        positions = list(string_default),
        rest = string_default
    )

    expect_true(schema_compact__same_node(pattern_container, pattern_container_default))
    expect_true(schema_compact__same_node(position_container, position_container_default))
    expect_true(schema_compact__same_node(
        SchemaNodeAllCmpt(branches = list(pattern_container, ref)),
        SchemaNodeAllCmpt(branches = list(pattern_container_default, ref))
    ))
    expect_true(schema_compact__same_node(
        SchemaNodeOneCmpt(branches = list(string, ref)),
        SchemaNodeOneCmpt(branches = list(string_default, ref))
    ))
    expect_false(schema_compact__same_node(
        SchemaNodeAllCmpt(branches = list(string, ref)),
        SchemaNodeAnyCmpt(branches = list(string_default, ref))
    ))
    expect_false(schema_compact__same_node(
        SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string"), desc = "first"),
        SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string"), desc = "second")
    ))
})

test_that("schema_compact__same_node() preserves exact binding shape", {
    target <- SchemaNodeLeaf(value = SchemaRuleCheck(kind = "string"))
    grouped <- SchemaNodeContainerCmpt(
        value = SchemaRuleCheck(kind = "list"),
        exact = list(SchemaBindingExactCmpt(keys = c("a", "b"), target = target))
    )
    separate <- SchemaNodeContainerCmpt(
        value = SchemaRuleCheck(kind = "list"),
        exact = list(
            SchemaBindingExactCmpt(keys = "a", target = target),
            SchemaBindingExactCmpt(keys = "b", target = target)
        )
    )

    expect_false(schema_compact__same_node(grouped, separate))
})

test_that("schema_compact() is idempotent and accepts raw DSL input", {
    schema <- schema_infer(
        list(items = list(list(id = 1L), list(id = 2L))),
        arrays = "rest"
    )
    compact <- schema_compact(schema)

    expect_equal(as.list(schema_compact(compact)), as.list(compact))
    expect_equal(as.list(schema_compact(as.list(schema))), as.list(compact))
})

test_that("schema_compact() container groups round-trip through DSL and JSON", {
    schema <- schema_compact(schema_infer(list(
        issued = list(`date-parts` = list(list(2024L))),
        created = list(`date-parts` = list(list(2024L))),
        `published-print` = list(`date-parts` = list(list(2024L)))
    ), arrays = "rest"))

    serialized <- as.list(schema)
    restored <- schema_doc(serialized)
    path <- tempfile(fileext = ".json")
    schema_write(schema, path)
    read <- schema_read(path)

    expect_equal(
        serialized$groups[[1L]],
        list(
            names = c("issued", "created", "published-print"),
            check = list(kind = "list"),
            fields = list(
                `date-parts` = list(
                    check = list(kind = "list"),
                    keys = list(type = "unnamed"),
                    rest = list(
                        check = list(kind = "list"),
                        keys = list(type = "unnamed"),
                        rest = list(check = list(kind = "int"))
                    )
                )
            )
        )
    )
    expect_equal(as.list(restored), serialized)
    expect_equal(as.list(read), serialized)
})
