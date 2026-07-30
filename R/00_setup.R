###############################################################################
# 00_setup.R
#
# Purpose:
# Global setup for the research project.
# - Load required packages
# - Define project paths
# - Set global options
# - Ensure reproducibility
#
# This script must be sourced FIRST.
###############################################################################

message("Running 00_setup.R ...")

# ---------------------------------------------------------------------------
# 1. Clean environment
# ---------------------------------------------------------------------------
rm(list = ls())
gc()

# ---------------------------------------------------------------------------
# 2. Required packages
# ---------------------------------------------------------------------------
required_packages <- c(
  "tidyverse",
  "here",
  "janitor",
  "fixest",
  "modelsummary",
  "readr"
)

installed <- rownames(installed.packages())
for (pkg in required_packages) {
  if (!pkg %in% installed) {
    install.packages(pkg)
  }
}

invisible(lapply(required_packages, library, character.only = TRUE))

# ---------------------------------------------------------------------------
# 3. Global options
# ---------------------------------------------------------------------------
options(
  scipen = 999,      # avoid scientific notation
  digits = 4
)

# Global seed constant. Every stochastic step must call set.seed(SEED).
SEED <- 123456
set.seed(SEED)

# ---------------------------------------------------------------------------
# Figure helper: all figures share dimensions and resolution.
# Usage: save_figure(my_plot, "outcome_density.png")
# ---------------------------------------------------------------------------
save_figure <- function(plot, filename,
                        width = 6.5, height = 4.5, dpi = 300) {
  ggplot2::ggsave(
    filename = here::here("paper", "figures", filename),
    plot     = plot,
    width    = width,
    height   = height,
    dpi      = dpi
  )
}

# ---------------------------------------------------------------------------
# 4. Project paths (DO NOT use setwd())
# ---------------------------------------------------------------------------
paths <- list(
  data_raw        = here::here("data", "raw"),
  data_interim    = here::here("data", "interim"),
  data_processed = here::here("data", "processed"),
  data_simulated  = here::here("data", "simulated"),
  data_final      = here::here("data", "final"),
  output_tables  = here::here("paper", "tables"),
  output_figures = here::here("paper", "figures"),
  output_models  = here::here("output", "models"),
  output_logs    = here::here("output", "logs")
)

# Create folders if they do not exist
dir.create(paths$data_raw, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$data_interim, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$data_processed, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$data_simulated, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$data_final, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$output_tables, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$output_figures, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$output_models, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$output_logs, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# 5. Sanity checks
# ---------------------------------------------------------------------------
stopifnot(dir.exists(paths$data_raw))
stopifnot(dir.exists(paths$data_interim))
stopifnot(dir.exists(paths$data_processed))
stopifnot(dir.exists(paths$data_simulated))
stopifnot(dir.exists(paths$data_final))

message("00_setup.R completed successfully.")
