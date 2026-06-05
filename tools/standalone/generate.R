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

imports <- standalone_description_field_inline(description, "Imports")
suggests <- standalone_description_field_inline(description, "Suggests")
optional_line <- if (nzchar(suggests)) {
    sprintf("- Optional package: %s.", suggests)
} else {
    "- Optional packages: none."
}

writeLines(
    c(
        "# schemate standalone bundle",
        "",
        "This branch contains the generated standalone schema bundle from `hongyuanjia/schemate`.",
        "",
        paste(
            "Use it when another R package needs schemate's schema construction,",
            "validation, query, and edit helpers without depending on the full development tree."
        ),
        "",
        "## Install",
        "",
        "```r",
        "usethis::use_standalone(\"hongyuanjia/schemate\", \"schema\", ref = \"standalone\")",
        "```",
        "",
        "This copies `R/standalone-schema.R` into your package.",
        "",
        "## Requirements",
        "",
        sprintf("- Required packages: %s.", imports),
        optional_line,
        "",
        "Declare these dependencies in the package that vendors the standalone file.",
        "",
        "## Example",
        "",
        "```r",
        "schema <- schema_compact(schema_infer(list(",
        "    id = 1L,",
        "    owner = list(login = \"alice\")",
        ")))",
        "",
        "schema_validate(schema, list(",
        "    id = 2L,",
        "    owner = list(login = \"bob\")",
        "))",
        "```",
        "",
        "## Maintenance",
        "",
        sprintf("This bundle was generated from source commit `%s`.", source_commit[[1L]]),
        "",
        paste(
            "Do not edit files on this branch by hand. Make changes on the main branch,",
            "update the standalone generator or source files, and regenerate the branch."
        )
    ),
    file.path(out_dir, "README.md")
)

message("Generated standalone bundle at ", normalizePath(out_dir, mustWork = FALSE))
