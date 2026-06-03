#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
    hit <- which(args == name)
    if (!length(hit) || hit[[1L]] == length(args)) {
        return(default)
    }
    args[[hit[[1L]] + 1L]]
}

script_arg <- commandArgs(FALSE)
script_file <- sub("^--file=", "", script_arg[startsWith(script_arg, "--file=")][[1L]])
script_file <- normalizePath(script_file, mustWork = TRUE)
repo <- normalizePath(file.path(dirname(script_file), "..", ".."), mustWork = TRUE)
out_dir <- arg_value("--out-dir", tempfile("schemate-standalone-"))

system2(
    file.path(R.home("bin"), "Rscript"),
    c(file.path(repo, "tools", "standalone", "generate.R"), "--out-dir", out_dir),
    stdout = TRUE,
    stderr = TRUE
)

standalone_file <- file.path(out_dir, "R", "standalone-schema.R")
if (!file.exists(standalone_file)) {
    stop("Standalone file was not generated.", call. = FALSE)
}

source(standalone_file, chdir = TRUE)

schema <- schema_infer(list(id = 1L, name = "alice"))
schema <- schema_set_desc(schema, "$id", "Identifier")
schema_validate(schema, list(id = 2L, name = "bob"))

json_path <- tempfile(fileext = ".json")
schema_write(schema, json_path)
restored <- schema_read(json_path)
schema_validate(restored, list(id = 3L, name = "carol"))

failed <- schema_validate(restored, list(id = "bad", name = "carol"), mode = "test")
if (isTRUE(failed)) {
    stop("Invalid input unexpectedly passed schema validation.", call. = FALSE)
}

target_pkg <- tempfile("schemate-target-")
dir.create(file.path(target_pkg, "R"), recursive = TRUE)
file.copy(standalone_file, file.path(target_pkg, "R", "import-standalone-schema.R"))
writeLines(c(
    "Package: schemate-target",
    "Title: Standalone Import Target",
    "Version: 0.0.0.9000",
    "Description: Temporary target package for standalone testing.",
    "License: MIT",
    "Encoding: UTF-8",
    "Imports:",
    "    checkmate (>= 2.0.0),",
    "    jsonlite,",
    "    S7"
), file.path(target_pkg, "DESCRIPTION"))

if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(target_pkg, quiet = TRUE)
    schema2 <- schema_infer(list(value = "ok"))
    schema_validate(schema2, list(value = "still ok"))
} else {
    source(file.path(target_pkg, "R", "import-standalone-schema.R"), chdir = TRUE)
}

message("Standalone local test passed.")
