#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_arg <- commandArgs(FALSE)
script_file <- sub("^--file=", "", script_arg[startsWith(script_arg, "--file=")][[1L]])
script_file <- normalizePath(script_file, mustWork = TRUE)
source(file.path(dirname(script_file), "utils.R"))

repo <- standalone_repo(script_file)
out_dir <- standalone_arg_value(args, "--out-dir", file.path(tempdir(), "schemate-standalone"))

source_description <- standalone_source_description(repo)
description <- standalone_bundle_description(repo)
source_files <- standalone_source_files(repo, source_description)

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
    sprintf("# imports: [%s]", standalone_description_field_inline(description, "Imports")),
    sprintf("# optional: [%s]", standalone_description_field_inline(description, "Suggests")),
    sprintf("# source-commit: %s", source_commit[[1L]]),
    "# ---",
    "#",
    comment_lines(news),
    "#",
    "# nocov start",
    ""
)

body <- unlist(
    lapply(source_files, function(path) {
        c(
            sprintf("# %s %s", strrep("-", 20), basename(path)),
            standalone_clean_source_lines(path),
            ""
        )
    }),
    use.names = FALSE
)

footer <- c("# nocov end", "")

dir.create(file.path(out_dir, "R"), recursive = TRUE, showWarnings = FALSE)
writeLines(c(header, body, footer), file.path(out_dir, "R", "standalone-schema.R"))
standalone_write_description(description, file.path(out_dir, "DESCRIPTION"))

writeLines(
    c(
        "YEAR: 2026",
        "COPYRIGHT HOLDER: Hongyuan Jia"
    ),
    file.path(out_dir, "LICENSE")
)

writeLines(
    c(
        "# schemate",
        "",
        "This branch is generated from `hongyuanjia/schemate`.",
        "",
        "```r",
        "usethis::use_standalone(\"hongyuanjia/schemate\", \"schema\", ref = \"standalone\")",
        "```"
    ),
    file.path(out_dir, "README.md")
)

message("Generated standalone bundle at ", normalizePath(out_dir, mustWork = FALSE))
