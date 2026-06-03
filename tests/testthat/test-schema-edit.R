expect_schema_edit_error <- function(expr, regexp) {
    msg <- tryCatch(
        {
            eval(substitute(expr), parent.frame())
            NA_character_
        },
        error = function(e) conditionMessage(e)
    )
    expect_match(msg, regexp)
}

test_that("schema_set_desc()", {
    doc <- schema_infer(list(id = 1L, name = "alice"))
    updated <- schema_set_desc(doc, "$id", "identifier field")
    removed <- schema_set_desc(updated, "$id", NULL)

    expect_equal(
        as.list(updated),
        list(
            check = list(kind = "list"),
            fields = list(
                id = list(description = "identifier field", check = list(kind = "int")),
                name = list(check = list(kind = "string"))
            )
        )
    )
    expect_equal(as.list(removed)$fields$id, list(check = list(kind = "int")))
})

test_that("schema fragment helpers create raw fragments consumed by edit verbs", {
    doc <- schema_add_def(schema_infer(list(id = 1L, flag = TRUE)), "text", list(check = list(kind = "string")))
    fragment <- schema_check("string", min.chars = 1L, description = "text node")

    checked <- schema_replace(doc, "$id", fragment)
    referenced <- schema_replace(doc, "$id", schema_ref("text", description = "shared text"))
    combined <- schema_replace(doc, "$id", schema_all(schema_check("string"), schema_ref("text")))
    negated <- schema_replace(doc, "$flag", schema_not(schema_check("null"), description = "not null"))
    raw <- schema_replace(doc, "$flag", list(any = list(list(check = list(kind = "null")), list(`$ref` = "#/$defs/text"))))

    expect_equal(fragment, list(description = "text node", check = list(kind = "string", min.chars = 1L)))
    expect_equal(schema_check("missing_kind"), list(check = list(kind = "missing_kind")))
    expect_equal(as.list(checked)$fields$id, list(description = "text node", check = list(kind = "string", min.chars = 1L)))
    expect_equal(as.list(referenced)$fields$id, list(description = "shared text", `$ref` = "#/$defs/text"))
    expect_equal(as.list(combined)$fields$id, list(all = list(list(check = list(kind = "string")), list(`$ref` = "#/$defs/text"))))
    expect_equal(as.list(negated)$fields$flag, list(description = "not null", not = list(check = list(kind = "null"))))
    expect_equal(as.list(raw)$fields$flag, list(any = list(list(check = list(kind = "null")), list(`$ref` = "#/$defs/text"))))

    expect_schema_edit_error(schema_replace(doc, "$id", schema_check("missing_kind")), "Invalid replacement")
    expect_schema_edit_error(schema_replace(doc, "$id", schema_ref("defs/text")), "definition name or a local ref")
    expect_schema_edit_error(schema_replace(doc, "$id", schema_all()), "requires at least one branch")
    expect_schema_edit_error(schema_replace(doc, "$id", schema_any(a = schema_check("string"))), "branches must be unnamed")
    expect_error(schema_check("string", kind = "int"), "must not include `kind`")
})

test_that("schema_doc() accepts raw group fragment syntax", {
    doc <- schema_doc(list(
        `$defs` = list(text = list(check = list(kind = "string"))),
        check = list(kind = "list"),
        groups = list(
            list(names = c("name", "label"), description = "name fields", `$ref` = "#/$defs/text"),
            list(names = c("start", "end"), any = list(list(kind = "null"), list(`$ref` = "#/$defs/text")))
        )
    ))

    expect_equal(
        as.list(doc),
        list(
            `$defs` = list(text = list(check = list(kind = "string"))),
            check = list(kind = "list"),
            groups = list(
                list(names = c("name", "label"), description = "name fields", `$ref` = "#/$defs/text"),
                list(
                    names = c("start", "end"),
                    any = list(
                        list(check = list(kind = "null")),
                        list(`$ref` = "#/$defs/text")
                    )
                )
            )
        )
    )
})

test_that("schema_replace()", {
    doc <- schema_infer(list(id = 1L, name = "alice"))
    nested <- schema_replace(doc, "$id", list(check = list(kind = "string")))
    root <- schema_replace(doc, "$", list(check = list(kind = "string")))

    expect_equal(
        as.list(nested),
        list(
            check = list(kind = "list"),
            fields = list(
                id = list(check = list(kind = "string")),
                name = list(check = list(kind = "string"))
            )
        )
    )
    expect_equal(as.list(root), list(check = list(kind = "string")))

    doc <- schema_infer(list(user = list(name = "alice"), id = 1L))
    updated <- schema_set_desc(doc, "$user$name", "user name")

    expect_equal(as.list(updated)$fields$user$fields$name$description, "user name")
    expect_equal(
        as.list(schema_set_desc(doc, "$fields$user$fields$name", "user name")),
        as.list(updated)
    )

    doc <- schema_infer(list(all = "x"))

    expect_schema_edit_error(schema_replace(doc, "$all", schema_check("string")), "does not exist")
    expect_equal(
        as.list(schema_replace(doc, "$fields$all", schema_check("character"))),
        list(
            check = list(kind = "list"),
            fields = list(all = list(check = list(kind = "character")))
        )
    )
    expect_schema_edit_error(schema_replace(doc, "$missing", schema_check("missing_kind")), "does not exist")
})

test_that("schema_replace() accepts schema_check() and schema_ref() helper calls", {
    doc <- schema_add_def(schema_infer(list(id = 1L, name = "alice")), "text", list(check = list(kind = "string")))

    checked <- schema_replace(doc, "$id", schema_check("string", min.chars = 1L, description = "identifier"))
    referenced <- schema_replace(doc, "$id", schema_ref("text", description = "shared text"))
    combined <- schema_replace(
        doc,
        "$id",
        schema_all(schema_check("string"), schema_ref("text"), description = "text-ish")
    )

    expect_equal(
        as.list(checked)$fields$id,
        list(description = "identifier", check = list(kind = "string", min.chars = 1L))
    )
    expect_equal(
        as.list(referenced)$fields$id,
        list(description = "shared text", `$ref` = "#/$defs/text")
    )
    expect_equal(
        as.list(combined)$fields$id,
        list(
            description = "text-ish",
            all = list(
                list(check = list(kind = "string")),
                list(`$ref` = "#/$defs/text")
            )
        )
    )
})

test_that("schema fragment helpers can be composed in raw lists", {
    doc <- schema_add_def(schema_infer(list(id = 1L)), "text", schema_check("string"))

    from_literal <- schema_replace(
        doc,
        "$id",
        list(any = list(schema_check("string"), schema_ref("text")))
    )

    expect_equal(
        as.list(from_literal)$fields$id,
        list(any = list(
            list(check = list(kind = "string")),
            list(`$ref` = "#/$defs/text")
        ))
    )

})

test_that("schema edit paths require matching combinator operators", {
    doc <- schema_replace(
        schema_infer(list(id = 1L)),
        "$id",
        schema_all(schema_check("int"))
    )
    negated <- schema_replace(
        schema_infer(list(flag = TRUE)),
        "$flag",
        schema_not(schema_check("null"))
    )

    expect_error(schema_replace(doc, "$id$any[1]", schema_check("number")), "does not exist")
    expect_error(schema_replace(negated, "$flag$any", schema_check("flag")), "does not exist")
})

test_that("schema fragment helpers are ordinary R functions", {
    doc <- schema_infer(list(id = 1L))

    stored <- schema_check("string")
    shadowed <- local({
        schema_check <- function() list(check = list(kind = "int"))
        schema_replace(doc, "$id", schema_check())
    })

    expect_equal(stored, list(check = list(kind = "string")))
    expect_equal(as.list(schema_replace(doc, "$id", stored))$fields$id, list(check = list(kind = "string")))
    expect_equal(as.list(shadowed)$fields$id, list(check = list(kind = "int")))
})

test_that("schema_replace() requires SchemaDoc as its first argument", {
    expect_error(
        schema_replace(
            list(
                check = list(kind = "list"),
                fields = list(id = list(check = list(kind = "int")))
            ),
            "$id",
            schema_check("string")
        ),
        "SchemaDoc|method"
    )
})

test_that("schema edit verbs require SchemaDoc inputs", {
    raw <- list(check = list(kind = "list"), fields = list(id = list(check = list(kind = "int"))))

    calls <- list(
        quote(schema_set_desc(raw, "$", "root")),
        quote(schema_set_keys(raw, "$", type = "named")),
        quote(schema_add_field(raw, "name", schema_check("string"))),
        quote(schema_add_group(raw, schema_group(c("name", "label"), schema_check("string")))),
        quote(schema_set_dynamic(raw, schema_check("string"))),
        quote(schema_del_keys(raw, "$")),
        quote(schema_del_field(raw, "id")),
        quote(schema_del_group(raw, 1L)),
        quote(schema_del_dynamic(raw)),
        quote(schema_add_def(raw, "text", schema_check("string"))),
        quote(schema_del_def(raw, "text"))
    )

    for (call in calls) {
        expect_error(eval(call), "method|dispatch|SchemaDoc")
    }
})

test_that("schema_set_keys()", {
    doc <- schema_infer(list(id = 1L, name = "alice"))
    with_keys <- schema_set_keys(doc, "$", type = "named", must.include = "id")
    without_keys <- schema_del_keys(with_keys, "$")
    referenced <- schema_replace(
        schema_add_def(doc, "text", schema_check("string")),
        "$id",
        schema_ref("text")
    )

    expect_equal(as.list(with_keys)$keys, list(type = "named", must.include = "id"))
    expect_false("keys" %in% names(as.list(without_keys)))
    expect_error(schema_set_keys(referenced, "$id", type = "named"), "only allowed on check nodes")
    expect_error(schema_del_keys(doc, "$"), "does not exist")
    expect_identical(schema_del_keys(doc, "$", error_if_missing = FALSE), doc)
})

test_that("schema_add_field()", {
    doc <- schema_infer(list(id = 1L))
    updated <- schema_add_field(doc, "name", schema_check("string"))
    combined <- schema_add_field(
        updated,
        "maybe",
        schema_any(schema_check("null"), schema_check("string"))
    )

    expect_equal(
        as.list(updated),
        list(
            check = list(kind = "list"),
            fields = list(
                id = list(check = list(kind = "int")),
                name = list(check = list(kind = "string"))
            )
        )
    )
    expect_equal(
        as.list(combined)$fields$maybe,
        list(any = list(
            list(check = list(kind = "null")),
            list(check = list(kind = "string"))
        ))
    )

    expect_error(schema_add_field(updated, "name", list(check = list(kind = "string"))), "already exists")
    expect_schema_edit_error(schema_add_field(updated, "name", schema_check("missing_kind")), "already exists")
    expect_schema_edit_error(schema_add_field(updated, "new", schema_check("missing_kind"), path = "$id"), "does not identify a container")
    replaced <- schema_add_field(updated, "name", list(check = list(kind = "character")), overwrite = TRUE)
    expect_equal(as.list(replaced)$fields$name, list(check = list(kind = "character")))

    dynamic <- schema_add_field(updated, "*", schema_check("string"))
    expect_error(schema_add_field(dynamic, "*", schema_check("int")), "already exists")
    dynamic_replaced <- schema_add_field(dynamic, "*", schema_check("int"), overwrite = TRUE)
    expect_equal(as.list(dynamic_replaced)$fields$`*`, list(check = list(kind = "int")))
})

test_that("schema edit paths support non-letter field starts", {
    doc <- schema_infer(list(`_timestamp` = "2020", `1st` = 1L, `.meta` = TRUE, `*abc` = 2L))
    updated <- schema_replace(doc, "$_timestamp", schema_check("string", min.chars = 1L))
    updated <- schema_replace(updated, "$1st", schema_check("number"))
    updated <- schema_replace(updated, "$.meta", schema_check("flag"))
    updated <- schema_replace(updated, "$*abc", schema_check("integer"))

    expect_equal(as.list(updated)$fields$`_timestamp`, list(check = list(kind = "string", min.chars = 1L)))
    expect_equal(as.list(updated)$fields$`1st`, list(check = list(kind = "number")))
    expect_equal(as.list(updated)$fields$`.meta`, list(check = list(kind = "flag")))
    expect_equal(as.list(updated)$fields$`*abc`, list(check = list(kind = "integer")))
})

test_that("schema edit paths support quoted field names with path operators", {
    doc <- schema_infer(list(`a$b` = 1L, `x[1]` = "value"))
    updated <- schema_replace(doc, "$`a$b`", schema_check("number"))
    updated <- schema_replace(updated, "$fields$`x[1]`", schema_check("character"))

    expect_equal(as.list(updated)$fields$`a$b`, list(check = list(kind = "number")))
    expect_equal(as.list(updated)$fields$`x[1]`, list(check = list(kind = "character")))
})

test_that("schema edit paths reject ambiguous separators and indexes", {
    doc <- schema_infer(list(id = 1L))

    expect_error(schema_set_desc(doc, "$$id", "identifier"), "empty segment")
    expect_error(schema_set_desc(doc, "$id$", "identifier"), "empty segment")
    expect_error(schema_set_desc(doc, "$fields$$id", "identifier"), "empty segment")
    expect_error(schema_set_desc(doc, "$fields$[1]", "identifier"), "empty segment")
    expect_error(schema_set_desc(doc, "$id[]", "identifier"), "Unsupported path index")
    expect_error(schema_set_desc(doc, "$`id", "identifier"), "Unterminated quoted path segment")
    expect_error(schema_set_desc(doc, "$``", "identifier"), "empty quoted segment")
})

test_that("schema_add_group()", {
    doc <- schema_add_def(
        schema_infer(list(id = 1L)),
        "text",
        schema_any(schema_check("null"), schema_check("string"))
    )
    updated <- schema_add_group(doc, schema_group(c("name", "label"), schema_ref("text"), description = "name fields"))

    expect_equal(
        as.list(updated),
        list(
            `$defs` = list(text = list(any = list(
                list(check = list(kind = "null")),
                list(check = list(kind = "string"))
            ))),
            check = list(kind = "list"),
            fields = list(id = list(check = list(kind = "int"))),
            groups = list(
                list(names = c("name", "label"), description = "name fields", `$ref` = "#/$defs/text")
            )
        )
    )

    expect_schema_edit_error(
        schema_add_group(updated, schema_group(c("id", "alias"), schema_ref("text"))),
        "duplicated value"
    )
    expect_schema_edit_error(
        schema_add_group(updated, list(names = c("x", "y"), check = list(kind = "missing_kind")), path = "$id"),
        "does not identify a container"
    )

    replaced <- schema_replace(updated, "$groups[1]", schema_check("string", min.chars = 1L))
    described <- schema_set_desc(replaced, "$groups[1]", "shared names")

    expect_equal(
        as.list(replaced)$groups[[1L]],
        list(names = c("name", "label"), check = list(kind = "string", min.chars = 1L))
    )
    expect_equal(
        as.list(described)$groups[[1L]],
        list(names = c("name", "label"), description = "shared names", check = list(kind = "string", min.chars = 1L))
    )
})

test_that("schema_set_dynamic()", {
    doc <- schema_add_def(schema_infer(list(id = 1L)), "text", schema_check("string"))
    updated <- schema_set_dynamic(doc, schema_check("string"))
    replaced <- schema_set_dynamic(updated, schema_ref("text"))

    expect_equal(
        as.list(updated),
        list(
            `$defs` = list(text = list(check = list(kind = "string"))),
            check = list(kind = "list"),
            fields = list(
                id = list(check = list(kind = "int")),
                `*` = list(check = list(kind = "string"))
            )
        )
    )
    expect_equal(as.list(replaced)$fields$`*`, list(`$ref` = "#/$defs/text"))
    expect_schema_edit_error(schema_set_dynamic(doc, schema_check("missing_kind"), path = "$id"), "does not identify a container")
})

test_that("schema_del_field()", {
    doc <- schema_infer(list(id = 1L, name = "alice"))
    updated <- schema_del_field(doc, "name")

    expect_equal(
        as.list(updated),
        list(
            check = list(kind = "list"),
            fields = list(id = list(check = list(kind = "int")))
        )
    )
    expect_error(schema_del_field(updated, "name"), "does not exist")
    expect_identical(schema_del_field(updated, "name", error_if_missing = FALSE), updated)
})

test_that("schema_del_group()", {
    doc <- schema_doc(list(
        `$defs` = list(text = list(check = list(kind = "string"))),
        check = list(kind = "list"),
        groups = list(
            list(names = c("name", "label"), `$ref` = "#/$defs/text"),
            list(names = c("start", "end"), check = list(kind = "null"))
        )
    ))

    updated <- schema_del_group(doc, 1L)

    expect_equal(
        as.list(updated),
        list(
            `$defs` = list(text = list(check = list(kind = "string"))),
            check = list(kind = "list"),
            groups = list(
                list(names = c("start", "end"), check = list(kind = "null"))
            )
        )
    )

    expect_error(schema_del_group(updated, 2L), "does not exist")
    expect_error(schema_del_group(updated, 0L), ">= 1|positive")
    expect_identical(schema_del_group(updated, 2L, error_if_missing = FALSE), updated)
})

test_that("schema_del_dynamic()", {
    doc <- schema_set_dynamic(schema_infer(list(id = 1L)), schema_check("string"))
    updated <- schema_del_dynamic(doc)

    expect_equal(
        as.list(updated),
        list(
            check = list(kind = "list"),
            fields = list(id = list(check = list(kind = "int")))
        )
    )
    expect_error(schema_del_dynamic(updated), "Wildcard field does not exist")
    expect_identical(schema_del_dynamic(updated, error_if_missing = FALSE), updated)
})

test_that("schema_add_def()", {
    doc <- schema_infer(list(id = 1L))
    doc@path <- "inst/schema/example.json"
    updated <- schema_add_def(doc, "text", list(check = list(kind = "string")))

    expect_equal(updated@path, "inst/schema/example.json")
    expect_equal(as.list(updated)$`$defs`$text, list(check = list(kind = "string")))
    expect_error(schema_add_def(updated, "text", list(check = list(kind = "string"))), "already exists")
})

test_that("schema_del_def()", {
    doc <- schema_add_def(schema_infer(list(id = 1L)), "text", list(check = list(kind = "string")))
    updated <- schema_del_def(doc, "text")
    referenced <- schema_replace(doc, "$id", schema_ref("text"))

    expect_false("$defs" %in% names(as.list(updated)))
    expect_error(schema_del_def(updated, "text"), "does not exist")
    expect_identical(schema_del_def(updated, "text", error_if_missing = FALSE), updated)
    expect_error(schema_del_def(referenced, "text"), "still referenced")
})
