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
# Hourly treatment-control differences
# ---------------------------------------------------------------------------

# First sum the four quarter-hour readings for every household-hour. Hours with
# fewer than four valid readings are excluded so missing intervals cannot bias
# the group means downward. UTC defines unique hours across both DST changes;
# the plotted timestamps are subsequently displayed in Europe/Vienna time.
hourly_hh <- arrow::open_dataset(panel_path, unify_schemas = TRUE) |>
  dplyr::filter(
    date >= pre_start,
    date <= pre_end,
    is.na(vzp_id_source) | vzp_id_source != "synthetic"
  ) |>
  dplyr::select(
    time_utc, grid_operator, group_label, hh_id, cons_kwh_15m
  ) |>
  dplyr::mutate(hour_utc = floor_date(time_utc, "hour")) |>
  dplyr::group_by(hour_utc, grid_operator, group_label, hh_id) |>
  dplyr::summarise(
    hourly_kwh = sum(cons_kwh_15m, na.rm = TRUE),
    n_obs = sum(!is.na(cons_kwh_15m)),
    .groups = "drop"
  ) |>
  dplyr::filter(n_obs == 4) |>
  dplyr::collect() |>
  as.data.table()

hourly_stats <- hourly_hh[
  ,
  .(
    mean_kwh = mean(hourly_kwh),
    sd_kwh = sd(hourly_kwh),
    n_hh = uniqueN(hh_id)
  ),
  by = .(hour_utc, grid_operator, group_label)
]

make_hourly_difference <- function(stats, operator, treatment_groups) {
  control <- stats[
    grid_operator == operator & group_label == "Kontroll",
    .(
      hour_utc,
      control_mean = mean_kwh,
      control_sd = sd_kwh,
      control_n = n_hh
    )
  ]

  treatment <- stats[
    grid_operator == operator & group_label %in% treatment_groups,
    .(
      hour_utc,
      comparison = group_label,
      treatment_mean = mean_kwh,
      treatment_sd = sd_kwh,
      treatment_n = n_hh
    )
  ]

  result <- merge(treatment, control, by = "hour_utc", all = FALSE)
  result[, difference_kwh := treatment_mean - control_mean]
  result[, se_difference := sqrt(
    treatment_sd^2 / treatment_n + control_sd^2 / control_n
  )]
  result[, ci_low := difference_kwh - 1.96 * se_difference]
  result[, ci_high := difference_kwh + 1.96 * se_difference]
  result <- result[
    is.finite(difference_kwh) & is.finite(ci_low) & is.finite(ci_high)
  ]
  result[, hour_local := with_tz(hour_utc, "Europe/Vienna")]
  result[]
}

hourly_diff_ln <- make_hourly_difference(
  hourly_stats, "LN", c("Dynamisch", "Statisch")
)
hourly_diff_ln[, comparison := factor(
  comparison,
  levels = c("Dynamisch", "Statisch"),
  labels = c("Dynamisch − Kontrolle", "Statisch − Kontrolle")
)]

hourly_diff_noe <- make_hourly_difference(hourly_stats, "NOE", "Tarif")
hourly_diff_noe[, comparison := factor(
  comparison,
  levels = "Tarif",
  labels = "Tarif − Kontrolle"
)]

difference_colors <- c(
  "Dynamisch − Kontrolle" = "#00A08A",
  "Statisch − Kontrolle" = "#F2AD00",
  "Tarif − Kontrolle" = "#F98400"
)

p_ln <- ggplot(
  hourly_diff_ln,
  aes(
    x = hour_local, y = difference_kwh,
    colour = comparison, fill = comparison, group = comparison
  )
) +
  geom_hline(yintercept = 0, colour = "grey35", linewidth = 0.4) +
  geom_ribbon(aes(ymin = ci_low, ymax = ci_high), alpha = 0.10, colour = NA) +
  geom_line(linewidth = 0.25, alpha = 0.8) +
  scale_colour_manual(values = difference_colors) +
  scale_fill_manual(values = difference_colors) +
  scale_x_datetime(date_breaks = "2 months", date_labels = "%b\n%Y") +
  labs(
    title = "Stündliche Verbrauchsdifferenzen in der Vorperiode – Linz Netz",
    subtitle = "Treatment minus Kontrollgruppe; Bänder: 95%-Konfidenzintervalle",
    x = NULL,
    y = "Differenz des mittleren Strombezugs (kWh je Stunde)"
  ) +
  report_theme

p_noe <- ggplot(
  hourly_diff_noe,
  aes(
    x = hour_local, y = difference_kwh,
    colour = comparison, fill = comparison, group = comparison
  )
) +
  geom_hline(yintercept = 0, colour = "grey35", linewidth = 0.4) +
  geom_ribbon(aes(ymin = ci_low, ymax = ci_high), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.25, alpha = 0.85) +
  scale_colour_manual(values = difference_colors) +
  scale_fill_manual(values = difference_colors) +
  scale_x_datetime(date_breaks = "2 months", date_labels = "%b\n%Y") +
  labs(
    title = "Stündliche Verbrauchsdifferenz in der Vorperiode – Netz Oberösterreich",
    subtitle = "Tarifgruppe minus Kontrollgruppe; Band: 95%-Konfidenzintervall",
    x = NULL,
    y = "Differenz des mittleren Strombezugs (kWh je Stunde)"
  ) +
  report_theme

ggsave(
  file.path(fig_dir, "report_pt_ln_hourly_difference.png"),
  p_ln, width = 11.5, height = 6.0, dpi = 300
)
ggsave(
  file.path(fig_dir, "report_pt_noe_hourly_difference.png"),
  p_noe, width = 11.5, height = 6.0, dpi = 300
)

print(pretrend_balance)
message("02_parallel_trends.R completed successfully.")
