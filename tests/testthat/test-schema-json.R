test_that("schema_read()", {
    txt <- '{
      "version": "1.0.0",
      "$defs": {
        "text": {"check": {"kind": "string"}}
      },
      "description": "root alias",
      "$ref": "#/$defs/text"
    }'

    doc <- schema_read(txt)

    expect_true(S7::S7_inherits(doc, SchemaDoc))
    expect_equal(doc@version, "1.0.0")
    expect_null(doc@path)
    expect_equal(doc@root, SchemaNodeRef(desc = "root alias", ref = "#/$defs/text"))
    expect_named(doc@defs, "text")
})

test_that("schema_write()", {
    doc <- schema_doc(list(
        version = "1.2.3",
        `$defs` = list(text = list(check = list(kind = "string"))),
        description = "root alias",
        `$ref` = "#/$defs/text"
    ))

    json <- schema_utils__as_json(doc)
    expect_type(json, "character")
    expect_match(json, '"version"')
    expect_match(json, '"\\$defs"')

    path <- tempfile(fileext = ".json")
    expect_identical(schema_write(doc, path), path)
    expect_error(schema_write(doc, path), "File already exists")
    expect_identical(schema_write(doc, path, overwrite = TRUE), path)

    restored <- schema_read(path)
    expect_true(S7::S7_inherits(restored, SchemaDoc))
    expect_equal(restored@path, path)
    expect_equal(as.list(restored), as.list(doc))
})
