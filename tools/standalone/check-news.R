#!/usr/bin/env Rscript

if (identical(Sys.getenv("SCHEMATE_SKIP_STANDALONE_NEWS"), "1")) {
    quit(status = 0)
}

staged <- tryCatch(
    system2("git", c("diff", "--cached", "--name-only"), stdout = TRUE, stderr = FALSE),
    error = function(e) character()
)

if (!length(staged)) {
    quit(status = 0)
}

news <- "tools/standalone/NEWS.md"
# Keep this list focused on files that can change the generated standalone
# bundle's API or behavior. Workflow and vignette-only changes should not force
# standalone changelog churn.
relevant <- grepl(
    paste(c(
        "^R/schema-",
        "^DESCRIPTION$",
        "^tools/standalone/"
    ), collapse = "|"),
    staged
)

if (any(relevant) && !news %in% staged) {
    message(
        "Schema/standalone-related files changed, but ",
        news,
        " is not staged.\n",
        "Update the standalone changelog, or commit with ",
        "SCHEMATE_SKIP_STANDALONE_NEWS=1 if this change should not be recorded."
    )
    quit(status = 1)
}
