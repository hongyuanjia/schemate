test_that("SchemaNodeRef", {
    expect_error(SchemaNodeRef(ref = "ref"), "pattern")
    expect_error(SchemaNodeRef(desc = 1), "character")
    expect_error(SchemaNodeRef(desc = "desc"), "length 1")

    expect_true(S7::S7_inherits(SchemaNodeRef(ref = "#/$defs/text"), SchemaNodeRef))
    expect_equal(as.list(SchemaNodeRef(ref = "#/$defs/text")), list(`$ref` = "#/$defs/text"))
})

test_that("SchemaRuleCheck", {
    expect_error(SchemaRuleCheck(), "kind")
    expect_error(SchemaRuleCheck("string", NULL), "NULL")
    expect_error(SchemaRuleCheck("string", list(1)), "have names")
    expect_error(SchemaRuleCheck("tensor"), "be element of set")
    expect_error(SchemaRuleCheck("count", list(min.chars = 1)), "be a subset of")

    expect_true(S7::S7_inherits(SchemaRuleCheck("string", list(min.chars = 1L, null.ok = TRUE)), SchemaRuleCheck))
    expect_equal(
        as.list(SchemaRuleCheck("string", list(min.chars = 1L, null.ok = TRUE))),
        list(kind = "string", min.chars = 1L, null.ok = TRUE)
    )
})

test_that("SchemaBindingExactCmpt", {
    expect_error(
        SchemaBindingExactCmpt(
            keys = c("*", "b"),
            target = SchemaRuleCheck("string")
        ),
        "SchemaNode"
    )

    expect_true(
        S7::S7_inherits(
            SchemaBindingExactCmpt(
                keys = "a",
                target = SchemaNodeRef(ref = "#/$defs/value")
            ),
            SchemaBindingExactCmpt
        )
    )

    expect_true(
        S7::S7_inherits(
            SchemaBindingExactCmpt(
                keys = "*",
                target = SchemaNodeRef(ref = "#/$defs/value")
            ),
            SchemaBindingExactCmpt
        )
    )

    expect_true(
        S7::S7_inherits(
            SchemaBindingExactCmpt(
                keys = c("a", "b"),
                target = SchemaNodeRef(ref = "#/$defs/value")
            ),
            SchemaBindingExactCmpt
        )
    )

    expect_equal(
        as.list(SchemaBindingExactCmpt(
            keys = "a",
            target = SchemaNodeRef(ref = "#/$defs/value")
        )),
        list(fields = list(a = list(`$ref` = "#/$defs/value")))
    )

    expect_equal(
        as.list(SchemaBindingExactCmpt(
            keys = c("a", "b"),
            target = SchemaNodeRef(ref = "#/$defs/value")
        )),
        list(groups = list(names = c("a", "b"), `$ref` = "#/$defs/value"))
    )
})

test_that("SchemaNodeLeaf", {
    expect_error(
        SchemaNodeLeaf(value = SchemaRuleCheck("data_frame")),
        "container kind"
    )

    expect_true(
        S7::S7_inherits(
            SchemaNodeLeaf(value = SchemaRuleCheck("string")),
            SchemaNodeLeaf
        )
    )

    expect_equal(
        as.list(SchemaNodeLeaf(value = SchemaRuleCheck("string"))),
        list(check = list(kind = "string"))
    )

    expect_equal(
        as.list(SchemaNodeLeaf(desc = "a string", value = SchemaRuleCheck("string"))),
        list(description = "a string", check = list(kind = "string"))
    )

    expect_equal(
        as.list(SchemaNodeLeaf(
            value = SchemaRuleCheck("string"),
            name = SchemaRuleNames(list(type = "unique", must.include = "id"))
        )),
        list(
            check = list(kind = "string"),
            keys = list(type = "unique", must.include = "id")
        )
    )
})

test_that("SchemaNodeContainerCmpt", {
    grouped <- schema_spec__node(
        list(
            check = list(kind = "list"),
            groups = list(list(
                names = c("name", "label"),
                description = "shared names",
                check = list(kind = "string")
            ))
        ),
        root = FALSE
    )

    expect_equal(
        as.list(grouped)$groups[[1L]],
        list(names = c("name", "label"), description = "shared names", check = list(kind = "string"))
    )

    expect_error(
        SchemaNodeContainerCmpt(value = SchemaRuleCheck("string")),
        "container kind"
    )

    expect_error(
        SchemaNodeContainerCmpt(
            value = SchemaRuleCheck("data_frame", list(ncols = 10)),
            name = SchemaRuleNames(list(subset.of = c("a", "b"))),
            exact = list(
                SchemaBindingExactCmpt(keys = "id", target = SchemaNodeRef(ref = "#/$defs/id")),
                SchemaBindingExactCmpt(keys = "id", target = SchemaNodeLeaf(value = SchemaRuleCheck("string")))
            )
        ),
        "duplicated values"
    )

    expect_error(
        SchemaNodeContainerCmpt(
            value = SchemaRuleCheck("data_frame"),
            name = SchemaRuleCheck("string"),
        ),
        "SchemaRuleNames"
    )

    expect_true(
        S7::S7_inherits(
            SchemaNodeContainerCmpt(
                value = SchemaRuleCheck("data_frame"),
                name = SchemaRuleNames(),
            ),
            SchemaNodeContainerCmpt
        )
    )

    expect_equal(
        as.list(
            SchemaNodeContainerCmpt(
                value = SchemaRuleCheck("data_frame", list(ncols = 10)),
                name = SchemaRuleNames(list(subset.of = c("a", "b"))),
                exact = list(
                    SchemaBindingExactCmpt(keys = "id", target = SchemaNodeRef(ref = "#/$defs/id")),
                    SchemaBindingExactCmpt(
                        keys = c("name", "value"),
                        target = SchemaNodeLeaf(value = SchemaRuleCheck("string"))
                    )
                )
            )
        ),
        list(
            check = list(kind = "data_frame", ncols = 10),
            keys = list(subset.of = c("a", "b")),
            fields = list(id = list(`$ref` = "#/$defs/id")),
            groups = list(list(
                names = c("name", "value"),
                check = list(kind = "string")
            ))
        )
    )
})

test_that("SchemaNodeNary", {
    expect_error(
        SchemaNodeAllCmpt(
            branches = list(
                SchemaNodeLeaf(value = SchemaRuleCheck("string")),
                SchemaNodeRef(ref = "#/$defs/string"),
                list()
            )
        ),
        "SchemaNode"
    )

    expect_true(S7::S7_inherits(
        SchemaNodeAnyCmpt(
            branches = list(
                SchemaNodeLeaf(value = SchemaRuleCheck("string")),
                SchemaNodeRef(ref = "#/$defs/string")
            )
        ),
        SchemaNodeAnyCmpt
    ))

    expect_equal(
        as.list(SchemaNodeOneCmpt(
            branches = list(
                SchemaNodeLeaf(value = SchemaRuleCheck("string")),
                SchemaNodeRef(ref = "#/$defs/string")
            )
        )),
        list(
            one = list(
                list(check = list(kind = "string")),
                list(`$ref` = "#/$defs/string")
            )
        )
    )
})

test_that("schema_spec__rule()", {
    expect_error(
        schema_spec__rule(NULL, "$"),
        "list"
    )
    expect_error(
        schema_spec__rule(list(), "$"),
        "have names"
    )
    expect_error(
        schema_spec__rule(list("string"), "$"),
        "have names"
    )
    expect_error(
        schema_spec__rule(list(a = 1), "$"),
        "kind"
    )
    expect_error(
        schema_spec__rule(list(kind = "string", types = "a"), "$"),
        "invalid arguments"
    )
    expect_equal(
        schema_spec__rule(list(kind = "string", min.chars = 1L)),
        SchemaRuleCheck("string", list(min.chars = 1L))
    )
})

test_that("schema_spec__name_rule()", {
    expect_error(
        schema_spec__name_rule(NULL, "$"),
        "list"
    )
    expect_error(
        schema_spec__name_rule(list("string"), "$"),
        "have names"
    )
    expect_error(
        schema_spec__name_rule(list(a = 1), "$"),
        "invalid arguments"
    )
    expect_equal(
        schema_spec__name_rule(list(), "$"),
        SchemaRuleNames()
    )
    expect_equal(
        schema_spec__name_rule(list(type = "unique"), "$"),
        SchemaRuleNames(list(type = "unique"))
    )
})

test_that("schema_spec__node() dispatches by primary operator", {
    expect_equal(
        schema_spec__node(list(check = list(kind = "string"))),
        SchemaNodeLeaf(value = SchemaRuleCheck("string"))
    )
    expect_equal(
        schema_spec__node(
            list(`$ref` = "#/$defs/value"),
            # can skip ref target checking if defs is NULL
            defs = NULL,
            root = FALSE
        ),
        SchemaNodeRef(ref = "#/$defs/value")
    )
    expect_equal(
        schema_spec__node(
            list(`$ref` = "#/$defs/value"),
            defs = "value",
            root = FALSE
        ),
        SchemaNodeRef(ref = "#/$defs/value")
    )
    expect_error(
        schema_spec__node(
            list(`$ref` = "#/$defs/value"),
            defs = character(),
            root = FALSE
        ),
        "value"
    )
    expect_error(
        schema_spec__node(
            list(`$ref` = "#/$defs/missing"),
            defs = c("value", "text"),
            root = FALSE
        ),
        "missing"
    )

    sjson <- r"(
    {
      "description": "this is a full check node",
      "check": {"kind": "list"},
      "keys": {
        "type": "unique",
        "must.include": ["index_node", "parameter"]
      },
      "fields": {
        "index_node": {"check": {"kind": "string"}},
        "parameter": {
          "check": {"kind": "list"},
          "keys": {"type": "unique"},
          "groups": [
            {"names": ["latest", "distrib", "replica"], "$ref": "#/$defs/param_flag"},
            {"names": ["offset", "limit"], "$ref": "#/$defs/param_int"}
          ],
          "fields": {
            "format": {"$ref": "#/$defs/param_format"},
            "type": {"$ref": "#/$defs/param_type"},
            "fields": {"$ref": "#/$defs/param_character_vector"}
          },
          "patterns": {
            "^meta_": {"$ref": "#/$defs/param_character_vector"}
          },
          "rest": {"$ref": "#/$defs/param_generic"}
        }
      }
    }
    )"
    node <- expect_s7_class(schema_spec__node(schema_json__read_json(sjson), defs = NULL), SchemaNode)
    expect_equal(node@desc, "this is a full check node")
    expect_equal(node@value, SchemaRuleCheck("list"))
    expect_equal(node@name, SchemaRuleNames(list(type = "unique", `must.include` = c("index_node", "parameter"))))
    expect_equal(length(node@exact), 2L)
    expect_equal(
        node@exact[[1L]],
        SchemaBindingExactCmpt(keys = "index_node", target = SchemaNodeLeaf(value = SchemaRuleCheck("string")))
    )
    expect_error(
        schema_spec__node(
            schema_json__read_json('{"check":{"kind":"data_frame"},"fields":{"id":{"$ref":"#/$defs/missing"}}}'),
            defs = "value",
            root = FALSE
        ),
        "missing"
    )
    expect_error(
        schema_spec__node(
            schema_json__read_json('{"check":{"kind":"data_frame"},"fields":{"*":{"$ref":"#/$defs/missing"}}}'),
            defs = "value",
            root = FALSE
        ),
        "missing"
    )
    expect_error(
        schema_spec__node(
            schema_json__read_json('{"check":{"kind":"data_frame"},"rest":{"$ref":"#/$defs/missing"}}'),
            defs = "value",
            root = FALSE
        ),
        "missing"
    )
    expect_error(
        schema_spec__node(
            schema_json__read_json('{"check":{"kind":"data_frame"},"groups":[{"names":["name","label"],"$ref":"#/$defs/missing"}]}'),
            defs = "value",
            root = FALSE
        ),
        "missing"
    )

    sjson_all <- r"(
    {
      "description": "all node",
      "all": [
        {"kind": "string", "min.chars": 1},
        {"$ref": "#/$defs/text"},
        {"check": {"kind": "string", "pattern": "^[A-Z]+$"}}
      ]
    }
    )"
    node_all <- expect_s7_class(
        schema_spec__node(schema_json__read_json(sjson_all), defs = "text", root = FALSE),
        SchemaNodeAllCmpt
    )
    expect_equal(node_all@desc, "all node")
    expect_length(node_all@branches, 3L)
    expect_equal(node_all@branches[[1L]], SchemaNodeLeaf(value = SchemaRuleCheck("string", list(min.chars = 1L))))
    expect_equal(node_all@branches[[2L]], SchemaNodeRef(ref = "#/$defs/text"))
    expect_equal(
        node_all@branches[[3L]],
        SchemaNodeLeaf(value = SchemaRuleCheck("string", list(pattern = "^[A-Z]+$")))
    )
    expect_error(
        schema_spec__node(schema_json__read_json('{"all":[{"$ref":"#/$defs/missing"}]}'), defs = "text", root = FALSE),
        "missing"
    )

    sjson_any <- r"(
    {
      "description": "any node",
      "any": [
        {
          "check": {"kind": "list"},
          "fields": {
            "value": {"check": {"kind": "string"}}
          }
        },
        {"$ref": "#/$defs/generic"}
      ]
    }
    )"
    node_any <- expect_s7_class(
        schema_spec__node(schema_json__read_json(sjson_any), defs = "generic", root = FALSE),
        SchemaNodeAnyCmpt
    )
    expect_equal(node_any@desc, "any node")
    expect_length(node_any@branches, 2L)
    expect_s7_class(node_any@branches[[1L]], SchemaNodeContainerCmpt)
    expect_equal(node_any@branches[[2L]], SchemaNodeRef(ref = "#/$defs/generic"))

    sjson_one <- r"(
    {
      "one": [
        {"kind": "flag"},
        {"check": {"kind": "choice", "choices": ["a", "b"]}}
      ]
    }
    )"
    node_one <- expect_s7_class(
        schema_spec__node(schema_json__read_json(sjson_one), root = FALSE),
        SchemaNodeOneCmpt
    )
    expect_length(node_one@branches, 2L)
    expect_equal(node_one@branches[[1L]], SchemaNodeLeaf(value = SchemaRuleCheck("flag")))
    expect_equal(
        node_one@branches[[2L]],
        SchemaNodeLeaf(value = SchemaRuleCheck("choice", list(choices = c("a", "b"))))
    )

    sjson_not_ref <- r"(
    {
      "description": "not ref",
      "not": {"$ref": "#/$defs/text"}
    }
    )"
    node_not_ref <- expect_s7_class(
        schema_spec__node(schema_json__read_json(sjson_not_ref), defs = "text", root = FALSE),
        SchemaNodeNotCmpt
    )
    expect_equal(node_not_ref@desc, "not ref")
    expect_equal(node_not_ref@branch, SchemaNodeRef(ref = "#/$defs/text"))

    sjson_not_short <- r"(
    {
      "not": {"kind": "null"}
    }
    )"
    node_not_short <- expect_s7_class(
        schema_spec__node(schema_json__read_json(sjson_not_short), root = FALSE),
        SchemaNodeNotCmpt
    )
    expect_equal(node_not_short@branch, SchemaNodeLeaf(value = SchemaRuleCheck("null")))

    expect_error(
        schema_spec__node(schema_json__read_json('{"all":[]}'), root = FALSE),
        "length 0"
    )

    expect_error(
        schema_spec__node(schema_json__read_json('{"not":[]}'), root = FALSE),
        "valid schema node"
    )

    expect_error(
        schema_spec__node(schema_json__read_json('{"all":[],"any":[]}'), root = FALSE),
        "multiple found"
    )
    expect_error(
        schema_spec__node(schema_json__read_json('{"not":{"$ref":"#/$defs/missing"}}'), defs = "text", root = FALSE),
        "missing"
    )

    sjson_not_all <- r"(
    {
      "not": {
        "any": [
          { "$ref": "#/$defs/XX" },
          { "$ref": "#/$defs/YY" }
        ]
      }
    }
    )"
    node_not_all <- expect_s7_class(
        schema_spec__node(schema_json__read_json(sjson_not_all), defs = NULL, root = FALSE),
        SchemaNodeNotCmpt
    )
    expect_s7_class(node_not_all@branch, SchemaNodeAnyCmpt)
})

test_that("schema_spec__node_branch()", {
    short <- expect_s7_class(
        schema_spec__node_branch(
            schema_json__read_json('{"kind":"string","pattern":"^[0-9]+$"}'),
            path = "$all[1]",
            defs = character(),
            operator = "all"
        ),
        SchemaNodeLeaf
    )
    expect_equal(short@value, SchemaRuleCheck("string", list(pattern = "^[0-9]+$")))

    full <- expect_s7_class(
        schema_spec__node_branch(
            schema_json__read_json('{"$ref":"#/$defs/value"}'),
            path = "$all[2]",
            defs = "value",
            operator = "all"
        ),
        SchemaNodeRef
    )
    expect_equal(full@ref, "#/$defs/value")

    expect_error(
        schema_spec__node_branch(
            schema_json__read_json('{"$ref":"#/$defs/missing"}'),
            path = "$all[2]",
            defs = "value",
            operator = "all"
        ),
        "missing"
    )

    expect_error(
        schema_spec__node_branch(
            schema_json__read_json('{"description":"not allowed in shorthand","kind":"string"}'),
            path = "$all[2]",
            defs = character(),
            operator = "all"
        ),
        "description"
    )
})
