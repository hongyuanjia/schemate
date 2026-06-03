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
out_dir <- arg_value("--out-dir", file.path(tempdir(), "schemate-standalone"))

source_files <- file.path(
    repo,
    "R",
    c(
        "schema-utils.R",
        "schema-spec.R",
        "schema-doc.R",
        "schema-compact.R",
        "schema-edit.R",
        "schema-flat.R",
        "schema-infer.R",
        "schema-json.R",
        "schema-validate.R",
        "zzz.R"
    )
)

missing <- source_files[!file.exists(source_files)]
if (length(missing)) {
    stop("Missing source file(s): ", paste(missing, collapse = ", "), call. = FALSE)
}

source_commit <- tryCatch(
    system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(e) "unknown"
)
if (!length(source_commit)) {
    source_commit <- "unknown"
}

news_path <- file.path(repo, "tools", "standalone", "NEWS.md")
news <- if (file.exists(news_path)) {
    readLines(news_path, warn = FALSE)
} else {
    "# Standalone Changelog"
}

comment_lines <- function(lines) {
    if (!length(lines)) {
        return("#")
    }
    paste0("# ", lines)
}

header <- c(
    "# ---",
    "# repo: hongyuanjia/schemate",
    "# file: standalone-schema.R",
    paste0("# last-updated: ", Sys.Date()),
    "# license: MIT",
    "# imports: [S7, checkmate (>= 2.0.0), jsonlite, methods]",
    paste0("# source-commit: ", source_commit[[1L]]),
    "# ---",
    "#",
    comment_lines(news),
    "#",
    "# nocov start",
    ""
)

body <- unlist(lapply(source_files, function(path) {
    c(
        sprintf("# %s %s", strrep("-", 20), basename(path)),
        readLines(path, warn = FALSE),
        ""
    )
}), use.names = FALSE)

footer <- c("# nocov end", "")

dir.create(file.path(out_dir, "R"), recursive = TRUE, showWarnings = FALSE)
writeLines(c(header, body, footer), file.path(out_dir, "R", "standalone-schema.R"))

writeLines(c(
    "Package: schemate-standalone",
    "Title: Standalone Schema Bundle",
    "Version: 0.0.0.9000",
    "Author: Hongyuan Jia",
    "Maintainer: Hongyuan Jia <hongyuanjia@outlook.com>",
    "Description: Generated standalone schema bundle for usethis::use_standalone().",
    "License: MIT + file LICENSE",
    "Encoding: UTF-8",
    "Imports:",
    "    checkmate (>= 2.0.0),",
    "    jsonlite,",
    "    methods,",
    "    S7"
), file.path(out_dir, "DESCRIPTION"))

writeLines(c(
    "YEAR: 2026",
    "COPYRIGHT HOLDER: Hongyuan Jia"
), file.path(out_dir, "LICENSE"))

writeLines(c(
    "# schemate standalone",
    "",
    "This branch is generated from `hongyuanjia/schemate`.",
    "",
    "```r",
    "usethis::use_standalone(\"hongyuanjia/schemate\", \"schema\", ref = \"standalone\")",
    "```"
), file.path(out_dir, "README.md"))

message("Generated standalone bundle at ", normalizePath(out_dir, mustWork = FALSE))
