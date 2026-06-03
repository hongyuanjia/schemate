rule_check <- function(kind, args = list()) {
    SchemaRuleCheck(kind = kind, args = args)
}

test_that("schema_doc__defs())", {
    defs <- expect_type(
        schema_doc__defs(
            list(
                text = list(
                    description = "text def",
                    check = list(kind = "string", min.chars = 1L)
                ),
                code = list(check = list(kind = "string", pattern = "^[A-Z]+$")),
                value = list(check = list(kind = "string"))
            )
        ),
        "list"
    )
    expect_named(defs, c("text", "code", "value"))

    expect_error(schema_doc__defs(list("/" = list())), "contain '/'")
})

test_that("SchemaDoc", {
    expect_error(
        SchemaDoc(
            root = SchemaNodeLeaf(value = rule_check("string")),
            defs = list(text = rule_check("string"))
        ),
        "SchemaNode"
    )
    expect_error(
        SchemaDoc(
            root = SchemaNodeLeaf(value = rule_check("string")),
            version = 1
        ),
        "character"
    )

    doc <- SchemaDoc(
        root = SchemaNodeLeaf(
            desc = "root string",
            value = rule_check("string")
        ),
        defs = list(
            text = SchemaNodeLeaf(
                desc = "text def",
                value = rule_check("string", list(min.chars = 1L))
            )
        ),
        version = "1.0.0",
        path = "inst/schema/query.json"
    )

    expect_true(S7::S7_inherits(doc, SchemaDoc))
    expect_equal(doc@version, "1.0.0")
    expect_equal(doc@path, "inst/schema/query.json")
    expect_equal(
        as.list(doc),
        list(
            version = "1.0.0",
            description = "root string",
            `$defs` = list(
                text = list(
                    description = "text def",
                    check = list(kind = "string", min.chars = 1L)
                )
            ),
            check = list(kind = "string")
        )
    )
})

test_that("schema_doc()", {
    doc <- schema_doc(list(
        version = "2026.05",
        `$defs` = list(
            text = list(check = list(kind = "string", min.chars = 1L)),
            code = list(check = list(kind = "string", pattern = "^[A-Z]+$"))
        ),
        description = "query payload",
        check = list(kind = "data_frame"),
        groups = list(
            list(names = c("name", "label"), `$ref` = "#/$defs/text")
        ),
        fields = list(
            id = list(`$ref` = "#/$defs/code")
        ),
        rest = list(check = list(kind = "string", null.ok = TRUE))
    ))

    expect_true(S7::S7_inherits(doc, SchemaDoc))
    expect_equal(doc@version, "2026.05")
    expect_equal(names(doc@defs), c("text", "code"))
    expect_true(S7::S7_inherits(doc@root, SchemaNodeContainerCmpt))
    expect_equal(doc@root@desc, "query payload")
    expect_equal(doc@root@value, rule_check("data_frame"))
    expect_length(doc@root@exact, 2L)
    expect_equal(doc@root@exact[[1L]]@keys, "id")
    expect_equal(doc@root@exact[[1L]]@target, SchemaNodeRef(ref = "#/$defs/code"))
    expect_equal(doc@root@exact[[2L]]@keys, c("name", "label"))
    expect_equal(doc@root@exact[[2L]]@target, SchemaNodeRef(ref = "#/$defs/text"))
    expect_true(S7::S7_inherits(doc@root@rest, SchemaNodeLeaf))
    expect_equal(doc@root@rest@value, rule_check("string", list(null.ok = TRUE)))

    doc <- schema_doc(list(
        version = "v1",
        `$defs` = list(
            value = list(check = list(kind = "string"))
        ),
        description = "root alias",
        `$ref` = "#/$defs/value"
    ))

    expect_true(S7::S7_inherits(doc@root, SchemaNodeRef))
    expect_equal(doc@version, "v1")
    expect_equal(doc@root@ref, "#/$defs/value")
    expect_equal(doc@root@desc, "root alias")
    expect_equal(names(as.list(doc)), c("version", "description", "$defs", "$ref"))

    expect_error(
        schema_doc(list(`$defs` = list(value = list(check = list(kind = "string"))))),
        "root schema node"
    )

    expect_error(
        schema_doc(list(
            `$defs` = list("bad/name" = list(check = list(kind = "string"))),
            check = list(kind = "string")
        )),
        "must not contain '/'"
    )

    expect_error(
        schema_doc(list(
            check = list(kind = "data_frame"),
            fields = list(
                child = list(
                    `$defs` = list(value = list(check = list(kind = "string"))),
                    `$ref` = "#/$defs/value"
                )
            )
        )),
        "`\\$defs` is only allowed at the root schema document"
    )
    expect_error(
        schema_doc(list(version = 1, check = list(kind = "string"))),
        "character"
    )
    expect_error(
        schema_doc(list(
            check = list(kind = "data_frame"),
            fields = list(
                child = list(
                    version = "nested",
                    check = list(kind = "string")
                )
            )
        )),
        "version"
    )
})

test_that("schema_doc() supports positions", {
    doc <- schema_doc(list(
        `$defs` = list(text = list(check = list(kind = "string"))),
        description = "tuple payload",
        check = list(kind = "list", min.len = 2L),
        keys = list(type = "unnamed"),
        positions = list(
            list(`$ref` = "#/$defs/text"),
            list(check = list(kind = "int"))
        ),
        rest = list(check = list(kind = "number"))
    ))

    expect_true(S7::S7_inherits(doc@root, SchemaNodeContainerCmpt))
    expect_length(doc@root@positions, 2L)
    expect_equal(doc@root@positions[[1L]], SchemaNodeRef(ref = "#/$defs/text"))
    expect_equal(doc@root@positions[[2L]], SchemaNodeLeaf(value = rule_check("int")))
    expect_equal(
        as.list(doc),
        list(
            description = "tuple payload",
            `$defs` = list(text = list(check = list(kind = "string"))),
            check = list(kind = "list", min.len = 2L),
            keys = list(type = "unnamed"),
            positions = list(
                list(`$ref` = "#/$defs/text"),
                list(check = list(kind = "int"))
            ),
            rest = list(check = list(kind = "number"))
        )
    )

    expect_error(
        schema_doc(list(
            check = list(kind = "list"),
            positions = list(list(check = list(kind = "string")))
        )),
        "requires `keys\\$type = 'unnamed'`"
    )
    expect_error(
        schema_doc(list(
            check = list(kind = "list"),
            keys = list(type = "unnamed"),
            positions = list(first = list(check = list(kind = "string")))
        )),
        "May not have names"
    )
    expect_error(
        schema_doc(list(
            check = list(kind = "list"),
            keys = list(type = "unnamed"),
            fields = list(id = list(check = list(kind = "int")))
        )),
        "only allows `positions` and `rest`"
    )
    expect_error(
        schema_doc(list(
            check = list(kind = "list"),
            keys = list(type = "unnamed"),
            patterns = list("^id" = list(check = list(kind = "int")))
        )),
        "only allows `positions` and `rest`"
    )
    expect_error(
        schema_doc(list(
            check = list(kind = "string"),
            positions = list(list(check = list(kind = "string")))
        )),
        "'positions' is only allowed"
    )
})

test_that("as.list.SchemaDoc())", {
    # Contract: top-level order is version -> root description -> $defs -> root entries.
    doc <- schema_doc(list(
        version = "1.2.3",
        `$defs` = list(
            text = list(
                description = "text def",
                check = list(kind = "string")
            )
        ),
        description = "top any",
        any = list(
            list(kind = "string"),
            list(`$ref` = "#/$defs/text")
        )
    ))

    out <- as.list(doc)

    expect_equal(names(out), c("version", "description", "$defs", "any"))
    expect_equal(out$version, "1.2.3")
    expect_equal(names(out$`$defs`$text), c("description", "check"))
    expect_equal(names(out)[seq_len(3L)], c("version", "description", "$defs"))
    expect_equal(out$any[[1L]], list(check = list(kind = "string")))
    expect_equal(out$any[[2L]], list(`$ref` = "#/$defs/text"))

    doc_no_defs <- schema_doc(list(
        version = "2.0.0",
        description = "root string",
        check = list(kind = "string")
    ))
    expect_equal(
        as.list(doc_no_defs),
        list(
            version = "2.0.0",
            description = "root string",
            check = list(kind = "string")
        )
    )
    expect_equal(names(as.list(doc_no_defs)), c("version", "description", "check"))
})
