---
name: Research R Pipeline
description: Work with this research template's R pipeline. Use when editing masterfile.R, R scripts, data loading, cleaning, descriptives, analysis, tables, figures, or debugging reproducible R workflows.
---

# Research R Pipeline

## Project Structure

This template uses a staged R pipeline:

- `masterfile.R` runs the full workflow.
- `R/00_setup.R` loads packages and shared setup.
- `R/01_load_data.R` reads input data.
- `R/02_cleaning.R` creates analysis-ready data.
- `R/03_descriptives.R` creates descriptive summaries.
- `R/04_analysis.R` runs the main empirical analysis.
- `R/05_tables_figures.R` writes paper outputs.

## Instructions

1. Start by reading `masterfile.R` and the relevant stage scripts.
2. Keep raw data read-only. Do not modify files in `data/raw/`.
3. Prefer project-relative paths.
4. Write intermediate data to `data/interim/` or `data/processed/`.
5. Write final paper-ready outputs to `paper/tables/` and `paper/figures/`.
6. Keep scripts runnable from `source("masterfile.R")`.
7. Make outputs deterministic where possible by setting seeds for simulations or randomized steps.
8. When fixing errors, rerun the smallest relevant script first, then the full `masterfile.R`.

## Style

- Use clear section headers.
- Use object names that describe their role, such as `raw_data`, `analysis_data`, `descriptives_overall`, and `model_main`.
- Avoid hardcoded absolute paths.
- Keep package loading centralized in `R/00_setup.R`.
- Do not silently overwrite raw data.

## Packages and conventions

- Fixed-effects estimation: `fixest`. Regression tables: `modelsummary` (export `.tex` to `paper/tables/`). Never hand-type numbers into LaTeX tables.
- Paths: `here::here()` everywhere; never `setwd()` or absolute paths.
- One global seed constant defined in `R/00_setup.R` (`SEED`); every stochastic step references it via `set.seed(SEED)`.
- Large data: prefer `arrow`/parquet with column selection over reading full CSVs.
- Figures: `ggplot2`, saved via the `save_figure()` helper defined in `R/00_setup.R` (wraps `ggsave` with fixed width/height/dpi) so all figures share dimensions.

## Reproducibility

- Initialize `renv` in each cloned project (`renv::init()`, commit `renv.lock`).
- `masterfile.R` writes `sessionInfo()` to `output/logs/sessionInfo.txt` at the end of the run.

## Post-change verification checklist

1. Rerun the edited stage script in a clean session.
2. Rerun `source("masterfile.R")` fully.
3. Diff the regenerated files in `paper/tables/` and `paper/figures/`.
4. If any output changed, grep `paper/sections/` for the affected numbers and update the manuscript text.

