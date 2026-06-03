test_that("schema_validate()", {
    flat <- schema_flat__compile(schema_doc(list(check = list(kind = "string", pattern = "^[0-9]+$"))))

    expect_equal(schema_validate(flat, "123", mode = "check", name = "payload"), TRUE)
    expect_match(schema_validate(flat, "abc", mode = "check", name = "payload"), "payload")
    expect_true(schema_validate(flat, "123", mode = "test", name = "payload"))
    expect_false(schema_validate(flat, "abc", mode = "test", name = "payload"))

    ok_expectation <- schema_validate(flat, "123", mode = "expect", name = "payload")
    bad_expectation <- schema_validate(flat, "abc", mode = "expect", name = "payload")
    expect_s3_class(ok_expectation, "expectation")
    expect_s3_class(bad_expectation, "expectation")
    expect_true(ok_expectation$passed)
    expect_false(bad_expectation$passed)

    ok_assert <- withVisible(schema_validate(flat, "123", name = "payload"))
    expect_equal(ok_assert$value, "123")
    expect_false(ok_assert$visible)
    expect_error(schema_validate(flat, "abc", name = "payload"), "payload")

    open_doc <- schema_doc(list(
        check = list(kind = "data_frame"),
        keys = list(type = "unique", must.include = "id"),
        fields = list(
            id = list(check = list(kind = "int"))
        ),
        rest = list(check = list(kind = "string"))
    ))
    closed_doc <- schema_doc(list(
        check = list(kind = "data_frame"),
        fields = list(id = list(check = list(kind = "int")))
    ))
    named_leaf_schema <- schema_flat__compile(schema_doc(list(
        check = list(kind = "character"),
        keys = list(must.include = "id")
    )))
    keyed_list_schema <- schema_flat__compile(schema_doc(list(
        check = list(kind = "list"),
        fields = list(id = list(check = list(kind = "int")))
    )))

    open_schema <- schema_flat__compile(open_doc)
    closed_schema <- schema_flat__compile(closed_doc)

    expect_true(isTRUE(schema_validate(open_schema, data.frame(id = 1L, extra = "ok"), mode = "check", name = "payload")))
    expect_match(schema_validate(open_schema, data.frame(extra = "ok"), mode = "check", name = "payload"), "payload")
    expect_match(
        schema_validate(open_schema, data.frame(id = 1L, extra = 2L), mode = "check", name = "payload"),
        "payload\\$extra"
    )
    expect_match(
        schema_validate(closed_schema, data.frame(id = 1L, extra = "boom"), mode = "check", name = "payload"),
        "unexpected field"
    )
    expect_true(isTRUE(schema_validate(named_leaf_schema, c(id = "ok"), mode = "check", name = "payload")))
    expect_match(schema_validate(named_leaf_schema, "ok", mode = "check", name = "payload"), "payload")
    expect_match(schema_validate(keyed_list_schema, list(1L), mode = "check", name = "payload"), "named object")

    all_schema <- schema_flat__compile(schema_doc(list(
        all = list(
            list(kind = "string"),
            list(kind = "choice", choices = c("a", "b"))
        )
    )))
    any_schema <- schema_flat__compile(schema_doc(list(
        any = list(
            list(kind = "int"),
            list(kind = "string", pattern = "^[0-9]+$")
        )
    )))
    one_schema <- schema_flat__compile(schema_doc(list(
        one = list(
            list(kind = "string"),
            list(kind = "string", pattern = "^[0-9]+$")
        )
    )))
    not_schema <- schema_flat__compile(schema_doc(list(not = list(kind = "null"))))

    expect_true(isTRUE(schema_validate(all_schema, "a", mode = "check", name = "payload")))
    expect_match(schema_validate(all_schema, "z", mode = "check", name = "payload"), "payload")
    expect_true(isTRUE(schema_validate(any_schema, 1L, mode = "check", name = "payload")))
    expect_true(isTRUE(schema_validate(any_schema, "123", mode = "check", name = "payload")))
    expect_match(schema_validate(any_schema, TRUE, mode = "check", name = "payload"), "all branches of `any`")
    expect_match(schema_validate(any_schema, TRUE, mode = "check", name = "payload"), "\\[1\\].*\\[2\\]")
    expect_match(schema_validate(one_schema, TRUE, mode = "check", name = "payload"), "no branches of `one`")
    expect_match(schema_validate(one_schema, TRUE, mode = "check", name = "payload"), "\\[1\\].*\\[2\\]")
    expect_match(schema_validate(one_schema, "123", mode = "check", name = "payload"), "multiple branches of `one` \\(2\\)")
    expect_true(isTRUE(schema_validate(not_schema, "x", mode = "check", name = "payload")))
    expect_match(schema_validate(not_schema, NULL, mode = "check", name = "payload"), "`not` branch matched")

    doc <- schema_doc(list(
        `$defs` = list(
            child = list(
                check = list(kind = "list"),
                fields = list(leaf = list(check = list(kind = "string")))
            )
        ),
        check = list(kind = "list"),
        fields = list(child = list(`$ref` = "#/$defs/child"))
    ))

    flat <- schema_flat__compile(doc)
    expect_true(isTRUE(schema_validate(doc, list(child = list(leaf = "x")), mode = "test", name = "payload")))
    expect_match(
        schema_validate(flat, list(child = list(leaf = 1L)), mode = "check", name = "payload"),
        "payload\\$child\\$leaf"
    )
})

test_that("schema_validate applies rest to unnamed list elements", {
    doc <- schema_doc(list(
        check = list(kind = "list"),
        keys = list(type = "unnamed"),
        rest = list(
            check = list(kind = "list"),
            keys = list(type = "named", must.include = "family"),
            fields = list(
                family = list(check = list(kind = "string")),
                given = list(check = list(kind = "string"))
            )
        )
    ))

    x <- list(
        list(given = "Douglas", family = "Bates"),
        list(given = "Ben", family = "Bolker")
    )
    bad <- x
    bad[[2L]]$family <- 1L

    expect_true(isTRUE(schema_validate(doc, x, mode = "check", name = "payload")))
    expect_match(
        schema_validate(doc, bad, mode = "check", name = "payload"),
        "payload\\[\\[2\\]\\]\\$family"
    )
    expect_match(
        schema_validate(doc, stats::setNames(x, c("a", "b")), mode = "check", name = "payload"),
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
})

test_that("schema_validate applies positions before rest", {
    doc <- schema_doc(list(
        check = list(kind = "list", min.len = 2L),
        keys = list(type = "unnamed"),
        positions = list(
            list(check = list(kind = "string")),
            list(check = list(kind = "int"))
        ),
        rest = list(check = list(kind = "number"))
    ))
    closed_doc <- schema_doc(list(
        check = list(kind = "list"),
        keys = list(type = "unnamed"),
        positions = list(
            list(check = list(kind = "string")),
            list(check = list(kind = "int"))
        )
    ))
    exact_len_doc <- schema_doc(list(
        check = list(kind = "list", len = 3L),
        keys = list(type = "unnamed"),
        positions = list(
            list(check = list(kind = "string")),
            list(check = list(kind = "int")),
            list(check = list(kind = "number"))
        )
    ))

    expect_true(isTRUE(schema_validate(doc, list("x", 1L, 2.5), mode = "check", name = "payload")))
    expect_match(schema_validate(doc, list("x", "bad"), mode = "check", name = "payload"), "payload\\[\\[2\\]\\]")
    expect_match(schema_validate(doc, list("x", 1L, "bad"), mode = "check", name = "payload"), "payload\\[\\[3\\]\\]")
    expect_match(schema_validate(doc, list("x"), mode = "check", name = "payload"), "length >= 2")
    expect_true(isTRUE(schema_validate(closed_doc, list("x"), mode = "check", name = "payload")))
    expect_match(schema_validate(closed_doc, list("x", 1L, 2), mode = "check", name = "payload"), "unexpected position")
    expect_match(schema_validate(exact_len_doc, list("x", 1L), mode = "check", name = "payload"), "length 3")
    expect_match(
        schema_validate(doc, stats::setNames(list("x", 1L), c("a", "b")), mode = "check", name = "payload"),
        "May not have names"
    )
})

test_that("schema_validate applies patterns before rest", {
    doc <- schema_doc(list(
        check = list(kind = "list"),
        fields = list(
            id = list(check = list(kind = "int")),
            meta_exact = list(check = list(kind = "int"))
        ),
        patterns = list(
            "^meta_" = list(check = list(kind = "string")),
            "_flag$" = list(check = list(kind = "flag"))
        ),
        rest = list(check = list(kind = "number"))
    ))

    ok <- list(id = 1L, meta_exact = 2L, meta_name = "x", valid_flag = TRUE, score = 1)
    bad_pattern <- ok
    bad_pattern$meta_name <- 1L
    bad_multi <- ok
    bad_multi$meta_flag <- "yes"
    bad_rest <- ok
    bad_rest$score <- "high"

    expect_true(isTRUE(schema_validate(doc, ok, mode = "check", name = "payload")))
    expect_match(schema_validate(doc, bad_pattern, mode = "check", name = "payload"), "payload\\$meta_name")
    expect_match(schema_validate(doc, bad_multi, mode = "check", name = "payload"), "payload\\$meta_flag")
    expect_match(schema_validate(doc, bad_rest, mode = "check", name = "payload"), "payload\\$score")
})
