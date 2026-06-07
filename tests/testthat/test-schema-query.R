test_that("schema_paths() lists logical paths", {
    doc <- schema_doc(list(
        `$defs` = list(text = schema_check("string")),
        check = list(kind = "list"),
        groups = list(schema_group(
            c("issued", "created"),
            list(
                check = list(kind = "list"),
                fields = list(
                    `date-parts` = list(
                        check = list(kind = "list"),
                        keys = list(type = "unnamed"),
                        positions = list(schema_check("int")),
                        rest = schema_check("int")
                    )
                )
            )
        )),
        patterns = list(`^meta_` = schema_check("string")),
        rest = schema_check("null")
    ))

    paths <- schema_paths(doc)

    expect_true("$" %in% paths)
    expect_true("$issued" %in% paths)
    expect_true("$created" %in% paths)
    expect_true("$issued$`date-parts`$positions[1]" %in% paths)
    expect_true("$created$`date-parts`$rest" %in% paths)
    expect_true("$patterns$`^meta_`" %in% paths)
    expect_true("$rest" %in% paths)
    expect_true("$defs$text" %in% paths)
    expect_false(any(grepl("\\$groups", paths)))
    expect_false("$defs$text" %in% schema_paths(doc, defs = FALSE))
})

test_that("schema_find() filters by path and check kind", {
    doc <- schema_doc(list(
        check = list(kind = "list"),
        fields = list(
            id = schema_check("int"),
            name = schema_check("string")
        ),
        rest = schema_check("string")
    ))

    expect_equal(schema_find(doc, schema_where_path("^\\$id$")), "$id")
    expect_equal(sort(schema_find(doc, schema_where_check("string"))), sort(c("$name", "$rest")))
    expect_equal(schema_find(doc, schema_where_check("int")), "$id")
    expect_equal(schema_find(doc, schema_where_path("$name", fixed = TRUE)), "$name")
})

test_that("schema_find() validates predicates", {
    doc <- schema_infer(list(id = 1L))

    expect_error(schema_find(doc, TRUE), "Must be a function")
    expect_error(schema_find(doc, function(path, node) NA), "single TRUE or FALSE")
    expect_error(schema_find(doc, function(path, node) c(TRUE, FALSE)), "single TRUE or FALSE")
    expect_error(schema_where_check("missing_kind"), "Unsupported check kind")
})

test_that("schema_replace_where() batch replaces CrossRef-like date-parts", {
    doc <- schema_compact(schema_infer(
        list(
            issued = list(`date-parts` = list(list(2024L))),
            created = list(`date-parts` = list(list(2024L))),
            `published-online` = list(`date-parts` = list(list(2024L)))
        ),
        arrays = "rest"
    ))

    date_part <- list(
        check = list(kind = "list", min.len = 1L, max.len = 3L),
        keys = list(type = "unnamed"),
        positions = list(
            schema_check("int", lower = 0),
            schema_check("int", lower = 1, upper = 12),
            schema_check("int", lower = 1, upper = 31)
        )
    )

    updated <- schema_add_def(doc, "crossref_date_part", date_part)
    updated <- schema_replace_where(
        updated,
        schema_where_path("`date-parts`\\$rest$"),
        schema_ref("crossref_date_part")
    )

    paths <- schema_find(updated, schema_where_path("`date-parts`\\$rest$"))
    raw <- as.list(updated)

    expect_equal(length(paths), 3L)
    expect_null(raw$fields)
    expect_equal(raw$groups[[1L]]$names, c("issued", "created", "published-online"))
    expect_equal(raw$groups[[1L]]$fields$`date-parts`$rest, list(`$ref` = "#/$defs/crossref_date_part"))
})

test_that("schema_modify_where() can modify rest, position, pattern, and defs targets", {
    doc <- schema_doc(list(
        `$defs` = list(text = schema_check("string")),
        check = list(kind = "list"),
        patterns = list(`^meta_` = schema_check("string")),
        keys = list(type = "named"),
        fields = list(
            values = list(
                check = list(kind = "list"),
                keys = list(type = "unnamed"),
                positions = list(schema_check("int")),
                rest = schema_check("int")
            )
        )
    ))

    updated <- schema_replace_where(doc, schema_where_path("^\\$patterns"), schema_check("character"))
    updated <- schema_replace_where(updated, schema_where_path("positions\\[1\\]$"), schema_check("number"))
    updated <- schema_replace_where(updated, schema_where_path("\\$rest$"), schema_check("number"))
    updated <- schema_replace_where(updated, schema_where_path("^\\$defs\\$text$"), schema_check("character"))

    raw <- as.list(updated)
    expect_equal(raw$patterns$`^meta_`, list(check = list(kind = "character")))
    expect_equal(raw$fields$values$positions[[1L]], list(check = list(kind = "number")))
    expect_equal(raw$fields$values$rest, list(check = list(kind = "number")))
    expect_equal(raw$`$defs`$text, list(check = list(kind = "character")))
})

test_that("schema_modify_where() reports invalid replacement paths", {
    doc <- schema_infer(list(id = 1L))

    expect_identical(
        schema_modify_where(doc, schema_where_path("missing"), function(path, node) schema_check("string")),
        doc
    )
    expect_error(
        schema_modify_where(doc, schema_where_path("^\\$id$"), function(path, node) schema_check("missing_kind")),
        "Invalid replacement at path `\\$id`"
    )
})

test_that("schema_replace() and schema_set_desc() can target pattern paths", {
    doc <- schema_doc(list(
        check = list(kind = "list"),
        patterns = list(`^meta_` = schema_check("string"))
    ))

    updated <- schema_replace(doc, "$patterns$`^meta_`", schema_check("character"))
    updated <- schema_set_desc(updated, "$patterns$`^meta_`", "metadata value")

    raw <- as.list(updated)
    expect_equal(raw$patterns$`^meta_`$description, "metadata value")
    expect_equal(raw$patterns$`^meta_`$check, list(kind = "character"))
})

test_that("schema_modify_where() splits groups on partial logical field edits", {
    doc <- schema_doc(list(
        check = list(kind = "list"),
        groups = list(schema_group(c("id", "name"), schema_check("string")))
    ))

    updated <- schema_replace_where(doc, schema_where_path("^\\$id$"), schema_check("int"))
    raw <- as.list(updated)

    expect_null(raw$groups)
    expect_equal(raw$fields$id, list(check = list(kind = "int")))
    expect_equal(raw$fields$name, list(check = list(kind = "string")))
    expect_silent(schema_validate(updated, list(id = 1L, name = "a")))
    expect_error(schema_validate(updated, list(id = "a", name = "a")), "id")
})

test_that("schema_modify_where() preserves groups on full equivalent logical field edits", {
    doc <- schema_doc(list(
        check = list(kind = "list"),
        groups = list(schema_group(c("id", "name"), schema_check("string")))
    ))

    updated <- schema_replace_where(doc, schema_where_check("string"), schema_check("character"))
    raw <- as.list(updated)

    expect_null(raw$fields)
    expect_equal(raw$groups[[1L]]$names, c("id", "name"))
    expect_equal(raw$groups[[1L]]$check, list(kind = "character"))
    expect_silent(schema_validate(updated, list(id = "a", name = "b")))
    expect_error(schema_validate(updated, list(id = 1L, name = "b")), "id")
})

test_that("schema_modify_where() splits groups on differing full logical field edits", {
    doc <- schema_doc(list(
        check = list(kind = "list"),
        groups = list(schema_group(c("id", "name"), schema_check("string")))
    ))

    updated <- schema_modify_where(
        doc,
        schema_where_check("string"),
        function(path, node) {
            if (identical(path, "$id")) {
                schema_check("int")
            } else {
                schema_check("character")
            }
        }
    )
    raw <- as.list(updated)

    expect_null(raw$groups)
    expect_equal(raw$fields$id, list(check = list(kind = "int")))
    expect_equal(raw$fields$name, list(check = list(kind = "character")))
    expect_silent(schema_validate(updated, list(id = 1L, name = "a")))
})

test_that("schema_modify_where() protects against ancestor and descendant matches", {
    doc <- schema_doc(list(
        check = list(kind = "list"),
        fields = list(id = schema_check("int"))
    ))

    expect_error(
        schema_replace_where(doc, function(path, node) path %in% c("$", "$id"), schema_check("string")),
        "matched both ancestor path `\\$` and descendant path `\\$id`"
    )
})

test_that("schema_modify_where() supports missing behavior", {
    doc <- schema_infer(list(id = 1L))

    expect_identical(
        schema_replace_where(doc, schema_where_path("^\\$missing$"), schema_check("string")),
        doc
    )
    expect_identical(
        schema_replace_where(doc, schema_where_path("^\\$missing$"), schema_check("missing_kind")),
        doc
    )
    expect_error(
        schema_replace_where(doc, schema_where_path("^\\$missing$"), schema_check("string"), missing = "error"),
        "did not match any schema paths"
    )
})

test_that("schema_modify_where() wraps where and fn errors with path context", {
    doc <- schema_infer(list(id = 1L))

    expect_error(
        schema_find(doc, function(path, node) stop("boom")),
        "Failed to evaluate `where` at path `\\$`"
    )
    expect_error(
        schema_replace_where(doc, function(path, node) stop("boom"), schema_check("string")),
        "Failed to evaluate `where` at path `\\$`"
    )
    expect_error(
        schema_modify_where(doc, schema_where_path("^\\$id$"), function(path, node) stop("boom")),
        "Failed to modify schema node at path `\\$id`"
    )
    expect_error(
        schema_replace_where(doc, schema_where_path("^\\$id$"), schema_check("missing_kind")),
        "Invalid replacement at path `\\$id`"
    )
})

test_that("schema query and modify accept internal SchemaFlat objects", {
    doc <- schema_doc(list(
        check = list(kind = "list"),
        fields = list(
            values = list(
                check = list(kind = "list"),
                keys = list(type = "unnamed"),
                positions = list(schema_check("int")),
                rest = schema_check("int")
            )
        ),
        patterns = list(`^meta_` = schema_check("string"))
    ))
    flat <- schema_flat__compile(doc)

    paths <- schema_paths(flat)
    expect_true("$values$positions[1]" %in% paths)
    expect_true("$values$rest" %in% paths)
    expect_true("$patterns$`^meta_`" %in% paths)
    expect_equal(schema_find(flat, schema_where_path("positions\\[1\\]$")), "$values$positions[1]")

    updated <- schema_replace_where(flat, schema_where_path("positions\\[1\\]$"), schema_check("number"))
    expect_true(S7::S7_inherits(updated, SchemaFlat))
    expect_true(S7::S7_inherits(updated@root, SchemaNodeContainerFlat))
    expect_equal(as.list(updated)$fields$values$positions[[1L]], list(check = list(kind = "number")))
})

test_that("schema_replace_where() keeps cached raw replacements flat", {
    flat <- schema_flat__compile(schema_doc(list(
        check = list(kind = "list"),
        fields = list(
            a = schema_check("string"),
            b = schema_check("string")
        )
    )))
    replacement <- list(
        check = list(kind = "list"),
        fields = list(id = schema_check("int"))
    )

    updated <- schema_replace_where(flat, schema_where_check("string"), replacement)
    raw <- as.list(updated)

    expect_true(S7::S7_inherits(updated, SchemaFlat))
    expect_true(schema_flat__node_is_flat(updated@root@exact[[1L]]@target))
    expect_true(schema_flat__node_is_flat(updated@root@exact[[2L]]@target))
    expect_equal(raw$fields$a$fields$id, list(check = list(kind = "int")))
    expect_equal(raw$fields$b$fields$id, list(check = list(kind = "int")))
})

test_that("schema query and modify accept internal flat nodes", {
    flat <- schema_flat__compile(schema_infer(list(id = 1L)))
    node <- flat@root

    expect_equal(schema_find(node, schema_where_path("^\\$id$")), "$id")

    updated <- schema_replace_where(node, schema_where_path("^\\$id$"), schema_check("int", lower = 1))
    expect_true(schema_flat__node_is_flat(updated))
    expect_true(S7::S7_inherits(updated, SchemaNodeContainerFlat))
    expect_equal(as.list(updated)$fields$id, list(check = list(kind = "int", lower = 1)))
})
