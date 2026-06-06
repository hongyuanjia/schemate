standalone_arg_value <- function(args, name, default = NULL) {
    hit <- which(args == name)
    if (!length(hit) || hit[[1L]] == length(args)) {
        return(default)
    }
    args[[hit[[1L]] + 1L]]
}

standalone_repo <- function(script_file) {
    script_file <- normalizePath(script_file, mustWork = TRUE)
    normalizePath(file.path(dirname(script_file), "..", ".."), mustWork = TRUE)
}

standalone_source_description <- function(repo) {
    desc::description$new(file.path(repo, "DESCRIPTION"))
}

standalone_del_field <- function(description, field) {
    if (isTRUE(description$has_fields(field))) {
        description$del(field)
    }
    invisible(description)
}

standalone_bundle_description <- function(repo) {
    description <- standalone_source_description(repo)

    tryCatch(description$del_collate(), error = function(e) NULL)
    description$del_dep("testthat", type = "all")
    standalone_del_field(description, "Config/testthat/edition")
    standalone_del_field(description, "Roxygen")
    standalone_del_field(description, "RoxygenNote")

    description
}

standalone_write_description <- function(description, path) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    description$write(path)
    invisible(path)
}

standalone_description_field <- function(description, field) {
    value <- description$get(field)
    if (length(value) == 0L || all(is.na(value))) {
        return("")
    }
    unname(value[[1L]])
}

standalone_description_field_inline <- function(description, field) {
    trimws(gsub("\\s+", " ", standalone_description_field(description, field)))
}

standalone_description_deps <- function(description) {
    description$get_deps()
}

standalone_source_files <- function(repo, description = standalone_source_description(repo)) {
    collate <- description$get_collate()
    collate <- collate[!collate %in% c("schemate-package.R", "zzz.R")]
    source_files <- file.path(repo, "R", collate)

    missing <- source_files[!file.exists(source_files)]
    if (length(missing)) {
        stop("Missing source file(s): ", paste(missing, collapse = ", "), call. = FALSE)
    }

    source_files
}

standalone_clean_source_lines <- function(path) {
    lines <- readLines(path, warn = FALSE)
    lines <- lines[!startsWith(lines, "# vim: ")]
    lines <- lines[!grepl("^\\s*#' @include", lines, useBytes = TRUE)]
    lines <- lines[!grepl("^\\s*#' @rdname", lines, useBytes = TRUE)]
    gsub("\\s*#' @export\\s*$", "#' @noRd", lines, useBytes = TRUE)
}

standalone_required_files <- function(root) {
    file.path(root, c(
        "DESCRIPTION",
        "LICENSE",
        "README.md",
        file.path("R", "standalone-schema.R")
    ))
}

standalone_assert_files <- function(root) {
    required <- standalone_required_files(root)
    missing <- required[!file.exists(required)]
    if (length(missing)) {
        stop("Missing generated file(s): ", paste(missing, collapse = ", "), call. = FALSE)
    }
    invisible(required)
}

standalone_assert_description <- function(path, source_description) {
    description <- desc::description$new(path)

    for (field in c("Package", "Title", "Description")) {
        actual <- standalone_description_field(description, field)
        expected <- standalone_description_field(source_description, field)
        if (!identical(actual, expected)) {
            stop(sprintf("Generated DESCRIPTION field `%s` changed.", field), call. = FALSE)
        }
    }

    forbidden <- c("Collate", "Roxygen", "RoxygenNote", "Config/testthat/edition")
    present <- forbidden[vapply(forbidden, description$has_fields, logical(1L))]
    if (length(present)) {
        stop("Generated DESCRIPTION contains forbidden field(s): ", paste(present, collapse = ", "), call. = FALSE)
    }

    deps <- standalone_description_deps(description)
    if ("testthat" %in% deps$package) {
        stop("Generated DESCRIPTION must not depend on testthat.", call. = FALSE)
    }
    for (package in c("checkmate", "S7", "jsonlite")) {
        if (!package %in% deps$package) {
            stop(sprintf("Generated DESCRIPTION is missing dependency metadata for `%s`.", package), call. = FALSE)
        }
    }

    invisible(description)
}

standalone_copy_tree <- function(from, root) {
    if (!dir.exists(from)) {
        stop("Missing source directory: ", from, call. = FALSE)
    }

    target <- file.path(root, basename(from))
    unlink(target, recursive = TRUE, force = TRUE)
    ok <- file.copy(from, root, recursive = TRUE, copy.mode = FALSE, copy.date = FALSE)
    if (!isTRUE(ok)) {
        stop("Failed to copy directory: ", from, call. = FALSE)
    }

    target
}

standalone_copy_tests <- function(repo, root) {
    copied <- standalone_copy_tree(file.path(repo, "tests"), root)

    inst <- file.path(repo, "inst")
    if (dir.exists(inst)) {
        copied <- c(copied, standalone_copy_tree(inst, root))
    }

    invisible(copied)
}

standalone_remove_tests <- function(root) {
    unlink(file.path(root, c("tests", "inst")), recursive = TRUE, force = TRUE)
    invisible(root)
}

standalone_run_tests <- function(root) {
    if (!requireNamespace("testthat", quietly = TRUE)) {
        stop("Package `testthat` is required to run standalone tests.", call. = FALSE)
    }

    testthat::test_local(root, reporter = "summary", load_package = "source")
    invisible(root)
}
