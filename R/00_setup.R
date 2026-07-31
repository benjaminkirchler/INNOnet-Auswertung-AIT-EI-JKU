###############################################################################
# 00_setup.R
#
# Global setup for the report figures/tables pipeline.
# Loads only the final processed panel data - no raw loading/cleaning here.
###############################################################################

packages <- c(
  "here", "data.table", "arrow", "dplyr", "ggplot2", "lubridate",
  "tableone", "kableExtra", "tidyr", "readr"
)

missing_packages <- packages[!packages %in% rownames(installed.packages())]
if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}

invisible(lapply(packages, library, character.only = TRUE))
rm(missing_packages, packages)

options(stringsAsFactors = FALSE)
Sys.setenv(TZ = "Europe/Vienna")

paths <- list(
  panel_15m      = here::here("data", "processed", "roman_final", "panel_15m"),
  output          = here::here("output"),
  output_diagnostics = here::here("output", "diagnostics"),
  output_models   = here::here("output", "models"),
  output_tables  = here::here("paper", "tables"),
  output_figures = here::here("paper", "figures")
)

dir.create(paths$output, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$output_diagnostics, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$output_models, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$output_tables, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$output_figures, showWarnings = FALSE, recursive = TRUE)

stopifnot(dir.exists(paths$panel_15m))

save_figure <- function(plot, filename, width = 8, height = 4.5, dpi = 300) {
  ggplot2::ggsave(
    filename = filename,
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    bg = "white"
  )
}

message("00_setup.R completed successfully.")
