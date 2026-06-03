test_that("schema_infer is idempotent for SchemaDoc", {
    doc <- schema_doc(list(check = list(kind = "string")))

    expect_identical(schema_infer(doc), doc)
    expect_error(schema_infer(doc, version = "1.0.0"), "cannot be supplied")
    expect_error(schema_infer(doc, keys = "named"), "cannot be supplied")
    expect_error(schema_infer(doc, arrays = "rest"), "cannot be supplied")
})

test_that("schema_infer infers conservative atomic schemas", {
    expect_equal(as.list(schema_infer("x")), list(check = list(kind = "string")))
    expect_equal(as.list(schema_infer(c("x", "y"))), list(check = list(kind = "character")))
    expect_equal(as.list(schema_infer(1L)), list(check = list(kind = "int")))
    expect_equal(as.list(schema_infer(c(1L, 2L))), list(check = list(kind = "integer")))
})

test_that("schema_infer infers named list and data.frame fields", {
    named_list <- schema_infer(list(id = 1L, name = "alice"))
    data_frame <- schema_infer(data.frame(id = 1L, name = "alice"))

    expect_equal(
        as.list(named_list),
        list(
            check = list(kind = "list"),
            fields = list(
                id = list(check = list(kind = "int")),
                name = list(check = list(kind = "string"))
            )
        )
    )

    expect_equal(
        as.list(data_frame),
        list(
            check = list(kind = "data_frame"),
            fields = list(
                id = list(check = list(kind = "int")),
                name = list(check = list(kind = "string"))
            )
        )
    )
})

test_that("schema_infer keeps unnamed lists generic and preserves document metadata", {
    doc <- schema_infer(list(1L, "x"), version = "1.0.0")

    expect_s7_class(doc, SchemaDoc)
    expect_equal(doc@version, "1.0.0")
    expect_null(doc@path)
    expect_equal(as.list(doc), list(version = "1.0.0", check = list(kind = "list")))
})

test_that("schema_infer does not infer unnamed list element schemas", {
    expect_error(schema_infer(list(1L, "x"), keys = "unnamed"), "Must be element")
    expect_error(schema_infer(list(1L, "x"), keys = "required"), "requires named elements")
    expect_error(schema_infer(list(1L, "x"), keys = "exact"), "requires named elements")
})

test_that("schema_infer can infer unnamed lists as rest schemas", {
    expect_equal(
        as.list(schema_infer(list(), arrays = "rest")),
        list(
            check = list(kind = "list"),
            keys = list(type = "unnamed")
        )
    )
    expect_equal(
        as.list(schema_infer(list(1L, 2L), arrays = "rest")),
        list(
            check = list(kind = "list"),
            keys = list(type = "unnamed"),
            rest = list(check = list(kind = "int"))
        )
    )
    expect_equal(
        as.list(schema_infer(list(1L, "x"), arrays = "rest")),
        list(
            check = list(kind = "list"),
            keys = list(type = "unnamed"),
            rest = list(any = list(
                list(check = list(kind = "int")),
                list(check = list(kind = "string"))
            ))
        )
    )
    expect_equal(
        as.list(schema_infer(list(list(id = 1L), list(name = "alice")), arrays = "rest"))$rest,
        list(any = list(
            list(check = list(kind = "list"), fields = list(id = list(check = list(kind = "int")))),
            list(check = list(kind = "list"), fields = list(name = list(check = list(kind = "string"))))
        ))
    )
    expect_equal(
        as.list(schema_infer(list(list(1L, 2L), list("x")), arrays = "rest"))$rest,
        list(any = list(
            list(
                check = list(kind = "list"),
                keys = list(type = "unnamed"),
                rest = list(check = list(kind = "int"))
            ),
            list(
                check = list(kind = "list"),
                keys = list(type = "unnamed"),
                rest = list(check = list(kind = "string"))
            )
        ))
    )
})

test_that("schema_infer keeps nested unnamed lists conservative unless requested", {
    doc <- schema_infer(
        list(
            id = "work",
            author = list(
                list(given = "Douglas", family = "Bates"),
                list(given = "Ben", family = "Bolker")
            )
        ),
        keys = "required"
    )

    expect_equal(
        as.list(doc)$fields$author,
        list(check = list(kind = "list"))
    )

    doc <- schema_infer(
        list(
            id = "work",
            author = list(
                list(given = "Douglas", family = "Bates"),
                list(given = "Ben", family = "Bolker")
            )
        ),
        keys = "required",
        arrays = "rest"
    )

    expect_equal(
        as.list(doc)$fields$author$rest,
        list(
            check = list(kind = "list"),
            keys = list(type = "named", must.include = c("given", "family")),
            fields = list(
                given = list(check = list(kind = "string")),
                family = list(check = list(kind = "string"))
            )
        )
    )
})

test_that("schema_infer optionally infers names rules", {
    named_list <- list(id = 1L, name = "alice")
    named_scalar <- c(id = "alice")

    expect_equal(
        as.list(schema_infer(named_list, keys = "named")),
        list(
            check = list(kind = "list"),
            keys = list(type = "named"),
            fields = list(
                id = list(check = list(kind = "int")),
                name = list(check = list(kind = "string"))
            )
        )
    )

    expect_equal(
        as.list(schema_infer(named_list, keys = "required"))$keys,
        list(type = "named", must.include = c("id", "name"))
    )

    expect_equal(
        as.list(schema_infer(named_list, keys = "exact"))$keys,
        list(identical.to = c("id", "name"))
    )

    expect_equal(
        as.list(schema_infer(named_scalar, keys = "named")),
        list(check = list(kind = "string"), keys = list(type = "named"))
    )
})

test_that("schema_infer rejects unsupported inputs", {
    expect_error(schema_infer(new.env()), "does not support objects of class")
})
