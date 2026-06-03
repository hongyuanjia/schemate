# Generate curated real API payload fixtures for the API examples vignette.
#
# This script is intentionally not run during package checks. Run it manually
# when the bundled examples should be refreshed from the live APIs.

out_dir <- file.path("inst", "extdata", "api")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

read_api <- function(url) {
    jsonlite::fromJSON(
        url,
        simplifyVector = FALSE,
        simplifyDataFrame = FALSE,
        simplifyMatrix = FALSE
    )
}

keep <- function(x, fields) {
    x[intersect(fields, names(x))]
}

curate_owner <- function(x) {
    keep(x, c("login", "id", "node_id", "html_url", "type", "site_admin"))
}

curate_license <- function(x) {
    if (is.null(x)) {
        return(NULL)
    }

    keep(x, c("key", "name", "spdx_id", "url", "node_id"))
}

curate_repo <- function(x) {
    out <- keep(x, c(
        "id", "node_id", "name", "full_name", "private", "html_url",
        "description", "fork", "created_at", "updated_at", "pushed_at",
        "size", "stargazers_count", "watchers_count", "language",
        "has_issues", "has_projects", "has_downloads", "has_wiki",
        "has_pages", "has_discussions", "forks_count", "archived",
        "disabled", "open_issues_count", "allow_forking", "is_template",
        "topics", "visibility", "default_branch", "score"
    ))
    out$owner <- curate_owner(x$owner)
    out$license <- curate_license(x$license)
    out
}

curate_github <- function(x) {
    out <- keep(x, c("total_count", "incomplete_results", "items"))
    out$items <- lapply(x$items, curate_repo)
    out
}

curate_author <- function(x) {
    keep(x, c("given", "family", "sequence", "affiliation", "ORCID"))
}

curate_date <- function(x) {
    keep(x, c("date-parts", "date-time", "timestamp"))
}

curate_link <- function(x) {
    keep(x, c("URL", "content-type", "content-version", "intended-application"))
}

curate_work <- function(x) {
    out <- keep(x, c(
        "DOI", "type", "publisher", "title", "container-title",
        "short-container-title", "volume", "ISSN", "ISBN", "score", "URL",
        "reference-count", "is-referenced-by-count", "references-count"
    ))

    date_fields <- c(
        "issued", "created", "published", "published-online",
        "published-print", "deposited"
    )
    for (name in date_fields) {
        if (!is.null(x[[name]])) {
            out[[name]] <- curate_date(x[[name]])
        }
    }

    if (!is.null(x$author)) {
        out$author <- lapply(x$author, curate_author)
    }
    if (!is.null(x$link)) {
        out$link <- lapply(x$link, curate_link)
    }

    out
}

curate_crossref <- function(x) {
    out <- keep(x, c("status", "message-type", "message-version", "message"))
    out$message <- keep(x$message, c("total-results", "items-per-page", "query", "items"))
    out$message$items <- lapply(x$message$items, curate_work)
    out
}

write_fixture <- function(x, path) {
    jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
}

github_url <- "https://api.github.com/search/repositories?q=language:R+schema&per_page=2"
crossref_url <- "https://api.crossref.org/works?query.title=schema&rows=2"

github <- curate_github(read_api(github_url))
crossref <- curate_crossref(read_api(crossref_url))

write_fixture(github, file.path(out_dir, "github-search-repositories.json"))
write_fixture(crossref, file.path(out_dir, "crossref-works.json"))
