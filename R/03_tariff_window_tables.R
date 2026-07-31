###############################################################################
# 03_tariff_window_tables.R
#
# Purpose:
# Build the tariff-window exposure table and the hourly tariff/exception
# window shares table used in the Tarifdesign section.
###############################################################################

rm(list = ls())
gc()

message("Running 03_tariff_window_tables.R ...")

source(here::here("R", "00_setup.R"))

library(data.table)

options(arrow.use_threads = FALSE)

treatment_start <- as.Date("2025-08-01")

table_dir <- paths$output_tables
panel_path <- paths$panel_15m

group_levels <- c(
  "LN Kontroll",
  "LN Dynamisch",
  "LN Statisch",
  "NOÖ Kontroll",
  "NOÖ Tarif"
)

base_query <- arrow::open_dataset(panel_path, unify_schemas = TRUE) |>
  dplyr::filter(
    is.na(vzp_id_source) | vzp_id_source != "synthetic",
    is.na(drop) | drop == 0
  )

# ---------------------------------------------------------------------------
# Tariff-window exposure in the post period
# ---------------------------------------------------------------------------

signal_intervals <- base_query |>
  dplyr::filter(date >= treatment_start, treated == 1) |>
  dplyr::select(grid_operator, group_label, date, hour, hh_id, signal_value) |>
  dplyr::collect() |>
  as.data.table()

signal_intervals[, tariff_design := fcase(
  grid_operator == "LN" & group_label == "Statisch", "LN statisch",
  grid_operator == "LN" & group_label == "Dynamisch", "LN dynamisch",
  grid_operator == "NOE" & group_label == "Tarif", "NOÖ Tarif"
)]
signal_intervals <- signal_intervals[!is.na(tariff_design)]

# LN uses exception windows; NOÖ uses low/project/high tariff states.
signal_intervals[, ln_exception := grid_operator == "LN" & !is.na(signal_value) & signal_value < 0]
signal_intervals[, ln_rest := grid_operator == "LN" & !ln_exception]
signal_intervals[, noe_ht := grid_operator == "NOE" & !is.na(signal_value) & signal_value > 0]
signal_intervals[, noe_pt := grid_operator == "NOE" & !is.na(signal_value) & signal_value == 0]
signal_intervals[, noe_nt := grid_operator == "NOE" & !is.na(signal_value) & signal_value < 0]

tariff_exposure <- signal_intervals[
  ,
  .(
    n_hh = uniqueN(hh_id),
    total_intervals = .N,
    ln_exception_n = sum(ln_exception),
    ln_rest_n = sum(ln_rest),
    noe_ht_n = sum(noe_ht),
    noe_pt_n = sum(noe_pt),
    noe_nt_n = sum(noe_nt)
  ),
  by = tariff_design
]
tariff_exposure[, ln_exception_share := 100 * ln_exception_n / total_intervals]
tariff_exposure[, ln_rest_share := 100 * ln_rest_n / total_intervals]
tariff_exposure[, noe_ht_share := 100 * noe_ht_n / total_intervals]
tariff_exposure[, noe_pt_share := 100 * noe_pt_n / total_intervals]
tariff_exposure[, noe_nt_share := 100 * noe_nt_n / total_intervals]
tariff_exposure[, sort_order := match(tariff_design, c("LN statisch", "LN dynamisch", "NOÖ Tarif"))]
setorder(tariff_exposure, sort_order)
tariff_exposure[, sort_order := NULL]

fwrite(tariff_exposure, file.path(table_dir, "report_tariff_window_exposure.csv"))

tariff_table <- copy(tariff_exposure)
tariff_table[, ln_exception_print := fifelse(
  grepl("^LN", tariff_design),
  sprintf(
    "%s\\%% (%s)",
    formatC(ln_exception_share, format = "f", digits = 1, decimal.mark = ","),
    format(ln_exception_n, big.mark = ".", decimal.mark = ",")
  ),
  "--"
)]
tariff_table[, ln_rest_print := fifelse(
  grepl("^LN", tariff_design),
  sprintf(
    "%s\\%% (%s)",
    formatC(ln_rest_share, format = "f", digits = 1, decimal.mark = ","),
    format(ln_rest_n, big.mark = ".", decimal.mark = ",")
  ),
  "--"
)]
tariff_table[, noe_ht_print := fifelse(
  grepl("^NO", tariff_design),
  sprintf(
    "%s\\%% (%s)",
    formatC(noe_ht_share, format = "f", digits = 1, decimal.mark = ","),
    format(noe_ht_n, big.mark = ".", decimal.mark = ",")
  ),
  "--"
)]
tariff_table[, noe_pt_print := fifelse(
  grepl("^NO", tariff_design),
  sprintf(
    "%s\\%% (%s)",
    formatC(noe_pt_share, format = "f", digits = 1, decimal.mark = ","),
    format(noe_pt_n, big.mark = ".", decimal.mark = ",")
  ),
  "--"
)]
tariff_table[, noe_nt_print := fifelse(
  grepl("^NO", tariff_design),
  sprintf(
    "%s\\%% (%s)",
    formatC(noe_nt_share, format = "f", digits = 1, decimal.mark = ","),
    format(noe_nt_n, big.mark = ".", decimal.mark = ",")
  ),
  "--"
)]

tariff_lines <- c(
  "\\begin{table}[H]",
  "\\centering",
  "\\small",
  "\\caption{Verteilung der Tarif- und Ausnahmefenster in der Tarifphase}",
  "\\label{tab:tariff_window_exposure}",
  "\\begin{tabular}{lrrrrrr}",
  "\\toprule",
  "Tarifdesign & Haushalte & LN-Ausnahme & LN-Restzeit & NOÖ HT & NOÖ PT & NOÖ NT \\\\",
  "\\midrule",
  paste0(
    tariff_table$tariff_design, " & ",
    tariff_table$n_hh, " & ",
    tariff_table$ln_exception_print, " & ",
    tariff_table$ln_rest_print, " & ",
    tariff_table$noe_ht_print, " & ",
    tariff_table$noe_pt_print, " & ",
    tariff_table$noe_nt_print, " \\\\"
  ),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{flushleft}",
  "\\footnotesize Werte in Prozent der beobachteten 15-Minuten-Haushaltsintervalle; in Klammern: Anzahl der jeweiligen Intervalle. LN hat keine HT-/NT-Signale, sondern Ausnahmefenster und die übrige Restzeit. NOÖ HT/PT/NT bezeichnet Hoch-, Projekt-/Normal- und Niedrigtariffenster.",
  "\\end{flushleft}",
  "\\end{table}"
)

writeLines(
  tariff_lines,
  file.path(table_dir, "report_tariff_window_exposure.tex"),
  useBytes = TRUE
)

hourly_exposure <- signal_intervals[
  ,
  .(
    total_intervals = .N,
    ln_exception_n = sum(ln_exception),
    noe_ht_n = sum(noe_ht),
    noe_pt_n = sum(noe_pt),
    noe_nt_n = sum(noe_nt)
  ),
  by = .(tariff_design, hour)
]
hourly_exposure[, ln_exception_share := 100 * ln_exception_n / total_intervals]
hourly_exposure[, noe_ht_share := 100 * noe_ht_n / total_intervals]
hourly_exposure[, noe_pt_share := 100 * noe_pt_n / total_intervals]
hourly_exposure[, noe_nt_share := 100 * noe_nt_n / total_intervals]

hourly_table <- data.table(hour = 0:23)
hourly_table <- hourly_exposure[
  tariff_design == "LN statisch",
  .(hour, ln_static_exception = ln_exception_share)
][hourly_table, on = "hour"]
hourly_table <- hourly_exposure[
  tariff_design == "LN dynamisch",
  .(hour, ln_dynamic_exception = ln_exception_share)
][hourly_table, on = "hour"]
hourly_table <- hourly_exposure[
  tariff_design == "NOÖ Tarif",
  .(hour, noe_ht = noe_ht_share, noe_pt = noe_pt_share, noe_nt = noe_nt_share)
][hourly_table, on = "hour"]
setorder(hourly_table, hour)

fwrite(hourly_table, file.path(table_dir, "report_tariff_window_hourly_shares.csv"))

hourly_print <- copy(hourly_table)
hourly_print[, hour_print := sprintf("%02d:00--%02d:59", hour, hour)]
hourly_print[, ln_static_print := paste0(formatC(ln_static_exception, format = "f", digits = 1, decimal.mark = ","), "\\%")]
hourly_print[, ln_dynamic_print := paste0(formatC(ln_dynamic_exception, format = "f", digits = 1, decimal.mark = ","), "\\%")]
hourly_print[, noe_ht_print := paste0(formatC(noe_ht, format = "f", digits = 1, decimal.mark = ","), "\\%")]
hourly_print[, noe_pt_print := paste0(formatC(noe_pt, format = "f", digits = 1, decimal.mark = ","), "\\%")]
hourly_print[, noe_nt_print := paste0(formatC(noe_nt, format = "f", digits = 1, decimal.mark = ","), "\\%")]

hourly_lines <- c(
  "\\begin{table}[H]",
  "\\centering",
  "\\scriptsize",
  "\\caption{Tarif- und Ausnahmefenster nach Tagesstunde}",
  "\\label{tab:tariff_window_hourly_shares}",
  "\\setlength{\\tabcolsep}{4pt}",
  "\\begin{tabular}{lrrrrr}",
  "\\toprule",
  "Stunde & LN stat. & LN dyn. & NOÖ HT & NOÖ PT & NOÖ NT \\\\",
  "\\midrule",
  paste0(
    hourly_print$hour_print, " & ",
    hourly_print$ln_static_print, " & ",
    hourly_print$ln_dynamic_print, " & ",
    hourly_print$noe_ht_print, " & ",
    hourly_print$noe_pt_print, " & ",
    hourly_print$noe_nt_print, " \\\\"
  ),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{flushleft}",
  "\\footnotesize Werte zeigen pro Stunde den Anteil der beobachteten 15-Minuten-Haushaltsintervalle im jeweiligen Fenster. LN stat./dyn. bezeichnet den Anteil der Ausnahmefenster; die jeweilige Restzeit entspricht 100\\% minus Ausnahmefenster.",
  "\\end{flushleft}",
  "\\end{table}"
)

writeLines(
  hourly_lines,
  file.path(table_dir, "report_tariff_window_hourly_shares.tex"),
  useBytes = TRUE
)

message("03_tariff_window_tables.R completed successfully.")
