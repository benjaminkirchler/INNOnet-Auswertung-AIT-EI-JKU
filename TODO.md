# To-Do

Human-readable to-do list and single source of truth for tasks.
Agents keep this current; it is the plain-language translation of `AGENT_LOG.md`.

Regenerate the Overleaf annex after editing this file:

```r
source("R/99_generate_todo_annex.R")
```

Format (the R generator parses this table — keep the columns exactly):

- Priority: `high`, `medium`, `low`
- Status: `done`, `in-progress`, `pending`
- ID: unique integer, assigned in order

| Section | ID | Task | Priority | Status |
|---------|----|------|----------|--------|
| Setup | 1 | Rename repo and open the .Rproj in RStudio | high | pending |
| Setup | 2 | Run renv::init() and commit renv.lock | high | pending |
| Data | 3 | Place raw data in data/raw and fill in data/README.md codebook | high | pending |
| Analysis | 4 | Implement main specification in R/04_analysis.R | high | pending |
| Writing | 5 | Draft introduction using the introduction-formula reference | medium | pending |
| Prereg | 6 | Complete preregistration in prestudy/ and OSF/ | medium | pending |
