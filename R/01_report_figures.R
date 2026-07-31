###############################################################################
# 01_report_figures.R
#
# Purpose:
# Generate the descriptive figures and the 15-minute consumption distribution
# table for the report. Reads only the final processed panel_15m dataset.
###############################################################################

rm(list = ls())
gc()

message("Running 01_report_figures.R ...")

source(here::here("R", "00_setup.R"))

library(data.table)
library(ggplot2)
library(lubridate)

options(arrow.use_threads = FALSE)

treatment_start <- as.Date("2025-08-01")
pre_start <- as.Date("2024-08-01")
pre_end <- as.Date("2025-07-31")

fig_dir <- paths$output_figures
table_dir <- paths$output_tables
panel_path <- paths$panel_15m

group_colors <- c(
  "LN Kontroll" = "#5BBCD6",
  "LN Dynamisch" = "#00A08A",
  "LN Statisch" = "#F2AD00",
  "NOÖ Kontroll" = "#3B6FB6",
  "NOÖ Tarif" = "#F98400"
)

group_levels <- names(group_colors)

report_theme <- theme_minimal(base_size = 13) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold", size = 14),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 11)
  )

base_query <- arrow::open_dataset(panel_path, unify_schemas = TRUE) |>
  dplyr::filter(is.na(vzp_id_source) | vzp_id_source != "synthetic")

# ---------------------------------------------------------------------------
# Figure 0 and Table 0: 15-minute consumption distribution
# ---------------------------------------------------------------------------

cons_15m <- base_query |>
  dplyr::select(grid_operator, group_label, treated, cons_kwh_15m) |>
  dplyr::filter(!is.na(cons_kwh_15m), cons_kwh_15m >= 0) |>
  dplyr::collect() |>
  as.data.table()

cons_15m[, report_group := fcase(
  grid_operator == "LN" & group_label == "Kontroll", "LN Kontroll",
  grid_operator == "LN" & group_label == "Dynamisch", "LN Dynamisch",
  grid_operator == "LN" & group_label == "Statisch", "LN Statisch",
  grid_operator == "NOE" & group_label == "Kontroll", "NOÖ Kontroll",
  grid_operator == "NOE" & group_label == "Tarif", "NOÖ Tarif"
)]
cons_15m <- cons_15m[!is.na(report_group)]
cons_15m[, report_group := factor(report_group, levels = group_levels)]

cons_summary_all <- cons_15m[
  ,
  .(
    report_group = "Gesamt",
    n_15min = .N,
    zero_share = mean(cons_kwh_15m == 0),
    mean_kwh_15m = mean(cons_kwh_15m),
    median_kwh_15m = median(cons_kwh_15m),
    p90 = quantile(cons_kwh_15m, 0.90),
    p99 = quantile(cons_kwh_15m, 0.99),
    p995 = quantile(cons_kwh_15m, 0.995)
  )
]

cons_summary_group <- cons_15m[
  ,
  .(
    n_15min = .N,
    zero_share = mean(cons_kwh_15m == 0),
    mean_kwh_15m = mean(cons_kwh_15m),
    median_kwh_15m = median(cons_kwh_15m),
    p90 = quantile(cons_kwh_15m, 0.90),
    p99 = quantile(cons_kwh_15m, 0.99),
    p995 = quantile(cons_kwh_15m, 0.995)
  ),
  by = report_group
]
cons_summary_group[, report_group := as.character(report_group)]

cons_summary <- rbind(cons_summary_all, cons_summary_group, fill = TRUE)
cons_summary[, sort_order := match(report_group, c("Gesamt", group_levels))]
setorder(cons_summary, sort_order)
cons_summary[, sort_order := NULL]

fwrite(
  cons_summary,
  file.path(table_dir, "report_table_consumption_15m_distribution.csv")
)

cons_p995 <- cons_summary[report_group == "Gesamt", p995]
bin_width <- cons_p995 / 260

cons_density <- cons_15m[cons_kwh_15m <= cons_p995]
cons_density[, bin_left := floor(cons_kwh_15m / bin_width) * bin_width]
cons_density <- cons_density[
  ,
  .(n = .N),
  by = bin_left
]
cons_density[, density := n / (sum(n) * bin_width)]
setorder(cons_density, bin_left)

p0 <- ggplot(cons_density, aes(x = bin_left, y = density)) +
  geom_area(fill = "#6594C2", alpha = 0.35) +
  geom_line(colour = "#3B6FB6", linewidth = 0.8) +
  geom_vline(
    xintercept = cons_summary[report_group == "Gesamt", median_kwh_15m],
    linetype = "dashed",
    colour = "grey30"
  ) +
  geom_vline(
    xintercept = cons_summary[report_group == "Gesamt", p99],
    linetype = "dotted",
    colour = "grey30"
  ) +
  scale_x_continuous(limits = c(0, cons_p995), expand = expansion(mult = c(0, 0.01))) +
  labs(
    title = "Verteilung des Netzbezugs je 15 Minuten",
    subtitle = "Alle gültigen Viertelstundenwerte; x-Achse auf p99,5 begrenzt",
    x = "kWh je 15 Minuten",
    y = "Dichte"
  ) +
  report_theme +
  theme(legend.position = "none")

ggsave(
  file.path(fig_dir, "report_fig00_consumption_15m_density.png"),
  p0, width = 9, height = 5.5, dpi = 300
)

cons_table <- copy(cons_summary)
cons_table[, n_million := sprintf("%.1f", n_15min / 1e6)]
cons_table[, zero_share_print := sprintf("%.1f\\%%", 100 * zero_share)]
cons_table[, mean_print := sprintf("%.3f", mean_kwh_15m)]
cons_table[, median_print := sprintf("%.3f", median_kwh_15m)]
cons_table[, p90_print := sprintf("%.3f", p90)]
cons_table[, p99_print := sprintf("%.3f", p99)]
cons_table[, p995_print := sprintf("%.3f", p995)]

table_lines <- c(
  "\\begin{table}[H]",
  "\\centering",
  "\\caption{Verteilung des Netzbezugs auf Viertelstundenebene}",
  "\\label{tab:consumption_15m_distribution}",
  "\\begin{tabular}{lrrrrrrr}",
  "\\toprule",
  "Gruppe & $N$ (Mio.) & Nullanteil & Mittelwert & Median & p90 & p99 & p99,5 \\\\",
  "\\midrule",
  paste0(
    cons_table$report_group, " & ",
    cons_table$n_million, " & ",
    cons_table$zero_share_print, " & ",
    cons_table$mean_print, " & ",
    cons_table$median_print, " & ",
    cons_table$p90_print, " & ",
    cons_table$p99_print, " & ",
    cons_table$p995_print, " \\\\"
  ),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{flushleft}",
  "\\footnotesize Werte in kWh je 15 Minuten. Fehlende Werte sind ausgeschlossen.",
  "\\end{flushleft}",
  "\\end{table}"
)

writeLines(
  table_lines,
  file.path(table_dir, "report_table_consumption_15m_distribution.tex"),
  useBytes = TRUE
)

rm(cons_15m, cons_density, cons_summary, cons_summary_all, cons_summary_group, cons_table)
gc()

# ---------------------------------------------------------------------------
# Figure 1: Average daily consumption and feed-in
# ---------------------------------------------------------------------------

daily_hh <- base_query |>
  dplyr::select(
    date, grid_operator, group_label, hh_id,
    cons_kwh_15m, feed_in_kwh_15m
  ) |>
  dplyr::group_by(date, grid_operator, group_label, hh_id) |>
  dplyr::summarise(
    consumption_kwh = sum(cons_kwh_15m, na.rm = TRUE),
    feed_in_kwh = sum(feed_in_kwh_15m, na.rm = TRUE),
    n_obs = sum(!is.na(cons_kwh_15m)),
    .groups = "drop"
  ) |>
  dplyr::collect() |>
  as.data.table()

# Complete days only: keep household-days with as many valid 15-minute values
# as the fullest household on that date (96; 92/100 on the two DST days).
daily_hh[, expected_obs := max(n_obs), by = date]
daily_hh <- daily_hh[n_obs == expected_obs]

daily_hh[, report_group := fcase(
  grid_operator == "LN" & group_label == "Kontroll", "LN Kontroll",
  grid_operator == "LN" & group_label == "Dynamisch", "LN Dynamisch",
  grid_operator == "LN" & group_label == "Statisch", "LN Statisch",
  grid_operator == "NOE" & group_label == "Kontroll", "NOÖ Kontroll",
  grid_operator == "NOE" & group_label == "Tarif", "NOÖ Tarif"
)]
daily_hh <- daily_hh[!is.na(report_group)]
daily_hh[, report_group := factor(report_group, levels = group_levels)]
daily_hh[, dso_label := fifelse(grid_operator == "LN", "Linz Netz (LN)", "Netz Oberösterreich (NOÖ)")]

daily_group <- daily_hh[
  ,
  .(
    consumption_kwh = mean(consumption_kwh, na.rm = TRUE),
    feed_in_kwh = mean(feed_in_kwh, na.rm = TRUE)
  ),
  by = .(date, dso_label, report_group)
]

daily_long <- melt(
  daily_group,
  id.vars = c("date", "dso_label", "report_group"),
  measure.vars = c("consumption_kwh", "feed_in_kwh"),
  variable.name = "metric",
  value.name = "kwh_per_day"
)
daily_long[, metric := factor(
  metric,
  levels = c("consumption_kwh", "feed_in_kwh"),
  labels = c("Netzbezug", "Netzeinspeisung")
)]

p1 <- ggplot(daily_long, aes(x = date, y = kwh_per_day, colour = report_group)) +
  geom_line(linewidth = 0.35, alpha = 0.75) +
  geom_vline(xintercept = treatment_start, linetype = "dashed", colour = "grey35") +
  facet_grid(metric ~ dso_label, scales = "free_y") +
  scale_colour_manual(values = group_colors, drop = FALSE) +
  scale_x_date(date_breaks = "2 months", date_labels = "%b\n%Y") +
  labs(
    title = "Durchschnittlicher täglicher Netzbezug und Netzeinspeisung",
    x = NULL,
    y = "kWh je Haushalt und Tag"
  ) +
  report_theme

ggsave(
  file.path(fig_dir, "report_fig01_daily_consumption_feedin.png"),
  p1, width = 11, height = 6.5, dpi = 300
)

# ---------------------------------------------------------------------------
# Figure 2: Financial time series
# ---------------------------------------------------------------------------

daily_cost_hh <- base_query |>
  dplyr::select(
    date, grid_operator, group_label, hh_id,
    cons_kwh_15m, energy_tariff, grid_tariff
  ) |>
  dplyr::mutate(
    energy_cost_eur = cons_kwh_15m * energy_tariff,
    grid_cost_eur = cons_kwh_15m * grid_tariff
  ) |>
  dplyr::group_by(date, grid_operator, group_label, hh_id) |>
  dplyr::summarise(
    energy_cost_eur = sum(energy_cost_eur, na.rm = TRUE),
    grid_cost_eur = sum(grid_cost_eur, na.rm = TRUE),
    n_obs = sum(!is.na(cons_kwh_15m)),
    .groups = "drop"
  ) |>
  dplyr::collect() |>
  as.data.table()

# Complete days only (same rule as Figure 1).
daily_cost_hh[, expected_obs := max(n_obs), by = date]
daily_cost_hh <- daily_cost_hh[n_obs == expected_obs]

daily_cost_hh[, report_group := fcase(
  grid_operator == "LN" & group_label == "Kontroll", "LN Kontroll",
  grid_operator == "LN" & group_label == "Dynamisch", "LN Dynamisch",
  grid_operator == "LN" & group_label == "Statisch", "LN Statisch",
  grid_operator == "NOE" & group_label == "Kontroll", "NOÖ Kontroll",
  grid_operator == "NOE" & group_label == "Tarif", "NOÖ Tarif"
)]
daily_cost_hh <- daily_cost_hh[!is.na(report_group)]
daily_cost_hh[, report_group := factor(report_group, levels = group_levels)]
daily_cost_hh[, dso_label := fifelse(grid_operator == "LN", "Linz Netz (LN)", "Netz Oberösterreich (NOÖ)")]

daily_cost_group <- daily_cost_hh[
  ,
  .(
    energy_cost_eur = mean(energy_cost_eur, na.rm = TRUE),
    grid_cost_eur = mean(grid_cost_eur, na.rm = TRUE)
  ),
  by = .(date, dso_label, report_group)
]

cost_long <- melt(
  daily_cost_group,
  id.vars = c("date", "dso_label", "report_group"),
  measure.vars = c("energy_cost_eur", "grid_cost_eur"),
  variable.name = "cost_component",
  value.name = "eur_per_day"
)
cost_long[, cost_component := factor(
  cost_component,
  levels = c("energy_cost_eur", "grid_cost_eur"),
  labels = c("Energiekosten", "Netzkosten")
)]

p2 <- ggplot(cost_long, aes(x = date, y = eur_per_day, colour = report_group)) +
  geom_line(linewidth = 0.35, alpha = 0.75) +
  geom_vline(xintercept = treatment_start, linetype = "dashed", colour = "grey35") +
  facet_grid(cost_component ~ dso_label, scales = "free_y") +
  scale_colour_manual(values = group_colors, drop = FALSE) +
  scale_x_date(date_breaks = "2 months", date_labels = "%b\n%Y") +
  labs(
    title = "Variable Energie- und Netzkosten im Zeitverlauf",
    x = NULL,
    y = "Euro je Haushalt und Tag"
  ) +
  report_theme

ggsave(
  file.path(fig_dir, "report_fig02_financial_timeseries.png"),
  p2, width = 11, height = 6.5, dpi = 300
)

# ---------------------------------------------------------------------------
# Figure 3: Daily peaks
# ---------------------------------------------------------------------------

daily_peak_hh <- base_query |>
  dplyr::select(date, grid_operator, group_label, hh_id, cons_kwh_15m) |>
  dplyr::mutate(interval_kw = cons_kwh_15m * 4) |>
  dplyr::group_by(date, grid_operator, group_label, hh_id) |>
  dplyr::summarise(
    daily_peak_kw = max(interval_kw, na.rm = TRUE),
    n_obs = sum(!is.na(cons_kwh_15m)),
    .groups = "drop"
  ) |>
  dplyr::collect() |>
  as.data.table()

# Complete days only (same rule as Figure 1): a peak from a partial day is
# understated because intervals are missing.
daily_peak_hh[, expected_obs := max(n_obs), by = date]
daily_peak_hh <- daily_peak_hh[n_obs == expected_obs]

daily_peak_hh[, report_group := fcase(
  grid_operator == "LN" & group_label == "Kontroll", "LN Kontroll",
  grid_operator == "LN" & group_label == "Dynamisch", "LN Dynamisch",
  grid_operator == "LN" & group_label == "Statisch", "LN Statisch",
  grid_operator == "NOE" & group_label == "Kontroll", "NOÖ Kontroll",
  grid_operator == "NOE" & group_label == "Tarif", "NOÖ Tarif"
)]
daily_peak_hh <- daily_peak_hh[!is.na(report_group) & is.finite(daily_peak_kw)]
daily_peak_hh[, report_group := factor(report_group, levels = group_levels)]
daily_peak_hh[, dso_label := fifelse(grid_operator == "LN", "Linz Netz (LN)", "Netz Oberösterreich (NOÖ)")]

daily_peak_group <- daily_peak_hh[
  ,
  .(daily_peak_kw = mean(daily_peak_kw, na.rm = TRUE)),
  by = .(date, dso_label, report_group)
]

p3 <- ggplot(daily_peak_group, aes(x = date, y = daily_peak_kw, colour = report_group)) +
  geom_line(linewidth = 0.35, alpha = 0.75) +
  geom_vline(xintercept = treatment_start, linetype = "dashed", colour = "grey35") +
  facet_wrap(~dso_label, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = group_colors, drop = FALSE) +
  scale_x_date(date_breaks = "2 months", date_labels = "%b\n%Y") +
  labs(
    title = "Durchschnittliche tägliche Spitzenlast",
    x = NULL,
    y = "kW je Haushalt"
  ) +
  report_theme

ggsave(
  file.path(fig_dir, "report_fig03_daily_peaks.png"),
  p3, width = 11, height = 6.5, dpi = 300
)

# ---------------------------------------------------------------------------
# Figure 4: Typical 24-hour seasonal profiles
# ---------------------------------------------------------------------------

season_profile_hh <- base_query |>
  dplyr::filter(date >= pre_start, date <= pre_end) |>
  dplyr::select(date, hour, grid_operator, group_label, has_pv, hh_id, cons_kwh_15m) |>
  dplyr::group_by(date, hour, grid_operator, group_label, has_pv, hh_id) |>
  dplyr::summarise(
    kwh_hour = sum(cons_kwh_15m, na.rm = TRUE),
    n_obs = sum(!is.na(cons_kwh_15m)),
    .groups = "drop"
  ) |>
  dplyr::filter(n_obs == 4) |>
  dplyr::group_by(date, hour, grid_operator, group_label, has_pv) |>
  dplyr::summarise(avg_kw = mean(kwh_hour, na.rm = TRUE), .groups = "drop") |>
  dplyr::collect() |>
  as.data.table()

season_profile_hh[, report_group := fcase(
  grid_operator == "LN" & group_label == "Kontroll", "LN Kontroll",
  grid_operator == "LN" & group_label == "Dynamisch", "LN Dynamisch",
  grid_operator == "LN" & group_label == "Statisch", "LN Statisch",
  grid_operator == "NOE" & group_label == "Kontroll", "NOÖ Kontroll",
  grid_operator == "NOE" & group_label == "Tarif", "NOÖ Tarif"
)]
season_profile_hh <- season_profile_hh[!is.na(report_group)]
season_profile_hh[, report_group := factor(report_group, levels = group_levels)]
season_profile_hh[, dso_label := fifelse(grid_operator == "LN", "Linz Netz (LN)", "Netz Oberösterreich (NOÖ)")]
season_profile_hh[, pv_status := fifelse(has_pv == 1L, "PV-Haushalte", "Haushalte ohne PV")]
season_profile_hh[, pv_status := factor(pv_status, levels = c("Haushalte ohne PV", "PV-Haushalte"))]
season_profile_hh[, month := month(as.Date(date))]
season_profile_hh[, season := fcase(
  month %in% c(12, 1, 2), "Winter",
  month %in% c(3, 4, 5), "Frühling",
  month %in% c(6, 7, 8), "Sommer",
  month %in% c(9, 10, 11), "Herbst"
)]
season_profile_hh[, season := factor(season, levels = c("Frühling", "Sommer", "Herbst", "Winter"))]

season_profile <- season_profile_hh[
  ,
  .(avg_kw = mean(avg_kw, na.rm = TRUE)),
  by = .(dso_label, report_group, pv_status, season, hour)
]

p4 <- ggplot(season_profile, aes(x = hour, y = avg_kw, colour = report_group)) +
  geom_line(linewidth = 0.8) +
  facet_grid(pv_status + season ~ dso_label, scales = "free_y") +
  scale_colour_manual(values = group_colors, drop = FALSE) +
  scale_x_continuous(breaks = seq(0, 23, by = 4)) +
  labs(
    title = "Typische 24-Stunden-Profile vor Tarifbeginn nach Saison und PV-Status",
    x = "Stunde des Tages",
    y = "kW je Haushalt"
  ) +
  report_theme

ggsave(
  file.path(fig_dir, "report_fig05_seasonal_24h_profiles.png"),
  p4, width = 11.5, height = 11, dpi = 300
)

message("01_report_figures.R completed successfully.")
