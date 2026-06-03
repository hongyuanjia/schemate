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
relevant <- grepl(
    paste(c(
        "^R/schema-",
        "^schema-dsl[.]md$",
        "^vignettes/schema-dsl[.]Rmd$",
        "^tools/standalone/",
        "^.github/workflows/standalone[.]yaml$"
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
