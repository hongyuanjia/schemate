#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_arg <- commandArgs(FALSE)
script_file <- sub("^--file=", "", script_arg[startsWith(script_arg, "--file=")][[1L]])
script_file <- normalizePath(script_file, mustWork = TRUE)
source(file.path(dirname(script_file), "utils.R"))

repo <- standalone_repo(script_file)
out_dir <- standalone_arg_value(args, "--out-dir", tempfile("schemate-standalone-"))
source_description_path <- file.path(repo, "DESCRIPTION")
source_description <- standalone_source_description(repo)
source_description_before <- readLines(source_description_path, warn = FALSE)

output <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(file.path(repo, "tools", "standalone", "generate.R"), "--out-dir", out_dir),
    stdout = TRUE,
    stderr = TRUE
)
status <- attr(output, "status")
if (!is.null(status) && !identical(status, 0L)) {
    cat(output, sep = "\n")
    stop("Standalone generation failed.", call. = FALSE)
}

source_description_after <- readLines(source_description_path, warn = FALSE)
if (!identical(source_description_before, source_description_after)) {
    stop("Standalone generation modified the source package DESCRIPTION.", call. = FALSE)
}

standalone_assert_files(out_dir)
standalone_assert_description(file.path(out_dir, "DESCRIPTION"), source_description)

standalone_file <- file.path(out_dir, "R", "standalone-schema.R")
source(standalone_file, chdir = TRUE)

schema <- schema_infer(list(id = 1L, name = "alice"))
schema <- schema_set_desc(schema, "$id", "Identifier")
schema_validate(schema, list(id = 2L, name = "bob"))

if (requireNamespace("jsonlite", quietly = TRUE)) {
    json_path <- tempfile(fileext = ".json")
    schema_write(schema, json_path)
    restored <- schema_read(json_path)
    schema_validate(restored, list(id = 3L, name = "carol"))
} else {
    restored <- schema
}

failed <- schema_validate(restored, list(id = "bad", name = "carol"), mode = "test")
if (isTRUE(failed)) {
    stop("Invalid input unexpectedly passed schema validation.", call. = FALSE)
}

target_pkg <- tempfile("schemate-target-")
dir.create(file.path(target_pkg, "R"), recursive = TRUE)
file.copy(standalone_file, file.path(target_pkg, "R", "import-standalone-schema.R"))

target_description <- standalone_bundle_description(repo)
standalone_write_description(target_description, file.path(target_pkg, "DESCRIPTION"))
standalone_assert_description(file.path(target_pkg, "DESCRIPTION"), source_description)

if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(target_pkg, quiet = TRUE)
    schema2 <- schema_infer(list(value = "ok"))
    schema_validate(schema2, list(value = "still ok"))
} else {
    source(file.path(target_pkg, "R", "import-standalone-schema.R"), chdir = TRUE)
}

message("Standalone local test passed.")
