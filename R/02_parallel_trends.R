###############################################################################
# 02_parallel_trends.R
#
# Purpose:
# Simple pre-treatment parallel-trends checks for the report.
#
# Scope:
# - Uses only actual households; synthetic Kontroll+ is excluded.
# - Uses pre-treatment data only: 2024-08-01 to 2025-07-31.
###############################################################################

rm(list = ls())
gc()

message("Running 02_parallel_trends.R ...")

source(here::here("R", "00_setup.R"))

library(data.table)
library(ggplot2)
library(lubridate)

options(arrow.use_threads = FALSE)

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

# ---------------------------------------------------------------------------
# Household-day data
# ---------------------------------------------------------------------------

daily_hh <- arrow::open_dataset(panel_path, unify_schemas = TRUE) |>
  dplyr::filter(
    date >= pre_start,
    date <= pre_end,
    is.na(vzp_id_source) | vzp_id_source != "synthetic"
  ) |>
  dplyr::select(
    date, grid_operator, group_label, hh_id,
    cons_kwh_15m, feed_in_kwh_15m, net_kwh_15m
  ) |>
  dplyr::mutate(interval_kw = cons_kwh_15m * 4) |>
  dplyr::group_by(date, grid_operator, group_label, hh_id) |>
  dplyr::summarise(
    daily_kwh = sum(cons_kwh_15m, na.rm = TRUE),
    feed_in_kwh = sum(feed_in_kwh_15m, na.rm = TRUE),
    net_kwh = sum(net_kwh_15m, na.rm = TRUE),
    daily_peak_kw = max(interval_kw, na.rm = TRUE),
    n_obs = sum(!is.na(cons_kwh_15m)),
    .groups = "drop"
  ) |>
  dplyr::collect() |>
  as.data.table()

# Complete days only: a household-day counts when it has as many valid
# 15-minute values as the fullest household on that date (96; 92/100 on the
# two DST days). This keeps partial days from understating sums and peaks.
daily_hh[, expected_obs := max(n_obs), by = date]
daily_hh <- daily_hh[n_obs == expected_obs & is.finite(daily_peak_kw)]

daily_hh[, report_group := fcase(
  grid_operator == "LN" & group_label == "Kontroll", "LN Kontroll",
  grid_operator == "LN" & group_label == "Dynamisch", "LN Dynamisch",
  grid_operator == "LN" & group_label == "Statisch", "LN Statisch",
  grid_operator == "NOE" & group_label == "Kontroll", "NOÖ Kontroll",
  grid_operator == "NOE" & group_label == "Tarif", "NOÖ Tarif"
)]
daily_hh <- daily_hh[!is.na(report_group)]
daily_hh[, report_group := factor(report_group, levels = group_levels)]
daily_hh[, month_start := floor_date(date, "month")]
daily_hh[, dso_label := fifelse(grid_operator == "LN", "Linz Netz (LN)", "Netz Oberösterreich (NOÖ)")]

# ---------------------------------------------------------------------------
# Table: pre-treatment means by group
# ---------------------------------------------------------------------------

household_pre <- daily_hh[
  ,
  .(
    daily_kwh = mean(daily_kwh, na.rm = TRUE),
    feed_in_kwh = mean(feed_in_kwh, na.rm = TRUE),
    net_kwh = mean(net_kwh, na.rm = TRUE),
    daily_peak_kw = mean(daily_peak_kw, na.rm = TRUE)
  ),
  by = .(grid_operator, report_group, hh_id)
]

pretrend_balance <- household_pre[
  ,
  .(
    n_hh = uniqueN(hh_id),
    mean_daily_kwh = round(mean(daily_kwh, na.rm = TRUE), 2),
    median_daily_kwh = round(median(daily_kwh, na.rm = TRUE), 2),
    mean_feed_in_kwh = round(mean(feed_in_kwh, na.rm = TRUE), 2),
    mean_net_kwh = round(mean(net_kwh, na.rm = TRUE), 2),
    mean_daily_peak_kw = round(mean(daily_peak_kw, na.rm = TRUE), 2)
  ),
  by = .(grid_operator, report_group)
]
setorder(pretrend_balance, grid_operator, report_group)

fwrite(
  pretrend_balance,
  file.path(table_dir, "report_parallel_trends_balance.csv")
)

# ---------------------------------------------------------------------------
# Plot 1: monthly pre-trends, LN
# ---------------------------------------------------------------------------

# Two-stage aggregation so the confidence band is a CI over households:
# first the household's monthly mean, then mean/SD across those household
# means. Using the day-level SD with the household-level n would mix the two
# variance levels and mislabel the band.
monthly_hh_ln <- daily_hh[
  grid_operator == "LN",
  .(hh_month_kwh = mean(daily_kwh, na.rm = TRUE)),
  by = .(month_start, report_group, hh_id)
]
monthly_ln <- monthly_hh_ln[
  ,
  .(
    mean_daily_kwh = mean(hh_month_kwh),
    sd_daily_kwh = sd(hh_month_kwh),
    n_hh = uniqueN(hh_id)
  ),
  by = .(month_start, report_group)
]
monthly_ln[, se := sd_daily_kwh / sqrt(n_hh)]
monthly_ln[, ci_low := mean_daily_kwh - 1.96 * se]
monthly_ln[, ci_high := mean_daily_kwh + 1.96 * se]

p_ln <- ggplot(
  monthly_ln,
  aes(x = month_start, y = mean_daily_kwh, colour = report_group, fill = report_group)
) +
  geom_ribbon(aes(ymin = ci_low, ymax = ci_high), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.5) +
  scale_colour_manual(values = group_colors, limits = group_levels[1:3]) +
  scale_fill_manual(values = group_colors, limits = group_levels[1:3]) +
  scale_x_date(date_breaks = "1 month", date_labels = "%b\n%Y") +
  labs(
    title = "Vorperiodenverlauf des täglichen Netzbezugs in Linz Netz",
    x = NULL,
    y = "kWh je Haushalt und Tag"
  ) +
  report_theme

ggsave(
  file.path(fig_dir, "report_pt_ln_monthly_consumption.png"),
  p_ln, width = 10.5, height = 5.6, dpi = 300
)

# ---------------------------------------------------------------------------
# Plot 2: monthly pre-trends, NOÖ
# ---------------------------------------------------------------------------

# Same two-stage aggregation as for LN: CI over households.
monthly_hh_noe <- daily_hh[
  grid_operator == "NOE",
  .(hh_month_kwh = mean(daily_kwh, na.rm = TRUE)),
  by = .(month_start, report_group, hh_id)
]
monthly_noe <- monthly_hh_noe[
  ,
  .(
    mean_daily_kwh = mean(hh_month_kwh),
    sd_daily_kwh = sd(hh_month_kwh),
    n_hh = uniqueN(hh_id)
  ),
  by = .(month_start, report_group)
]
monthly_noe[, se := sd_daily_kwh / sqrt(n_hh)]
monthly_noe[, ci_low := mean_daily_kwh - 1.96 * se]
monthly_noe[, ci_high := mean_daily_kwh + 1.96 * se]

p_noe <- ggplot(
  monthly_noe,
  aes(x = month_start, y = mean_daily_kwh, colour = report_group, fill = report_group)
) +
  geom_ribbon(aes(ymin = ci_low, ymax = ci_high), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.5) +
  scale_colour_manual(values = group_colors, limits = group_levels[4:5]) +
  scale_fill_manual(values = group_colors, limits = group_levels[4:5]) +
  scale_x_date(date_breaks = "1 month", date_labels = "%b\n%Y") +
  labs(
    title = "Vorperiodenverlauf des täglichen Netzbezugs in Netz Oberösterreich",
    x = NULL,
    y = "kWh je Haushalt und Tag"
  ) +
  report_theme

ggsave(
  file.path(fig_dir, "report_pt_noe_monthly_consumption.png"),
  p_noe, width = 10.5, height = 5.6, dpi = 300
)

print(pretrend_balance)
message("02_parallel_trends.R completed successfully.")
