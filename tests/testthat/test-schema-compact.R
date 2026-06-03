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

test_that("schema_compact() is idempotent and rejects defs extraction", {
    schema <- schema_infer(
        list(items = list(list(id = 1L), list(id = 2L))),
        arrays = "rest"
    )
    compact <- schema_compact(schema)

    expect_equal(as.list(schema_compact(compact)), as.list(compact))
    expect_equal(as.list(schema_compact(as.list(schema))), as.list(compact))
    expect_error(schema_compact(schema, defs = TRUE), "not implemented")
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
