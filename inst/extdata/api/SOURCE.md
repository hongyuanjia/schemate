# API Payload Fixtures

These JSON files are curated subsets of real API responses captured on
2026-06-04:

- `github-search-repositories.json`
  - Source: `https://api.github.com/search/repositories?q=language:R+schema&per_page=2`
- `crossref-works.json`
  - Source: `https://api.crossref.org/works?query.title=schema&rows=2`

The fixtures keep original field values and nested JSON structure for the fields
that remain. They remove noisy fields such as large URL template blocks so the
vignette can focus on schema inference, compaction, editing, and validation.

To refresh these fixtures manually, run:

```r
source("data-raw/api-payloads.R")
```

Do not run the refresh script during package checks or vignette rendering; the
installed examples are intended to work offline.
