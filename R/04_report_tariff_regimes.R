###############################################################################
# 04_report_tariff_regimes.R
#
# Purpose:
# Generate German-language descriptive figures for the three consecutive
# NOE tariff-signal regimes. The figures are descriptive and are not causal
# estimators.
###############################################################################

message("Running 04_report_tariff_regimes.R ...")

source(here::here("R", "00_setup.R"))

options(arrow.use_threads = FALSE)

regime_dates <- list(
  regime_1 = c(as.Date("2025-08-01"), as.Date("2025-11-26")),
  regime_2 = c(as.Date("2025-11-27"), as.Date("2026-03-05")),
  regime_3 = c(as.Date("2026-03-06"), as.Date("2026-06-30"))
)

arm_colors <- c(
  "Kontrollgruppe" = "#7F7F7F",
  "Tarifgruppe" = "#F2AD00"
)
tariff_colors <- c(
  "Niedrigtarif" = "#B8D8BA",
  "Hochtarif" = "#E8B4B8"
)

regime_theme <- ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    legend.position = "top",
    panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(face = "bold"),
    plot.caption = ggplot2::element_text(
      size = 8,
      hjust = 0,
      lineheight = 1.05
    ),
    plot.margin = ggplot2::margin(10, 12, 12, 12)
  )

load_noe_regime <- function(start_date, end_date, include_rotation_group = FALSE) {
  selected_columns <- c(
    "vzp_id", "time", "date", "free_grid", "treated",
    "cons_kwh_15m", "signal_value"
  )
  if (include_rotation_group) {
    selected_columns <- c(selected_columns, "noe_group")
  }

  message(
    "Lese NOE-Panel vom ", start_date, " bis ", end_date, " ..."
  )

  panel <- arrow::open_dataset(paths$panel_15m, unify_schemas = TRUE) |>
    dplyr::filter(
      grid_operator == "NOE",
      is.na(vzp_id_source) | vzp_id_source != "synthetic",
      date >= start_date,
      date <= end_date
    ) |>
    dplyr::select(dplyr::all_of(selected_columns)) |>
    dplyr::collect()

  panel <- data.table::as.data.table(panel)
  panel <- panel[
    !is.na(cons_kwh_15m) &
      cons_kwh_15m >= 0 &
      cons_kwh_15m <= 12
  ]

  complete_days <- panel[
    ,
    .(observed_intervals = .N),
    by = .(vzp_id, date)
  ]
  complete_days[
    ,
    expected_intervals := max(observed_intervals),
    by = date
  ]
  panel <- panel[
    complete_days[
      observed_intervals == expected_intervals,
      .(vzp_id, date)
    ],
    on = .(vzp_id, date)
  ]

  timezone_ok <- !is.null(attr(panel$time, "tzone")) &&
    attr(panel$time, "tzone") == "Europe/Vienna"
  if (!timezone_ok) {
    stop("Die Zeitvariable des NOE-Panels muss Europe/Vienna verwenden.")
  }

  panel[
    ,
    clock_time := lubridate::hour(time) +
      lubridate::minute(time) / 60
  ]

  message(
    "Verbleibende Zeilen: ", nrow(panel),
    " | Haushalte: ", data.table::uniqueN(panel$vzp_id)
  )

  panel
}

create_sparse_regime_figure <- function(
    panel,
    regime_label,
    output_stem,
    recurring_share_threshold = NULL) {
  profiles <- panel[
    ,
    .(
      mean_grid_withdrawal_kwh = mean(cons_kwh_15m),
      households = data.table::uniqueN(vzp_id)
    ),
    by = .(treated, clock_time)
  ]
  profiles[
    ,
    arm := factor(
      data.table::fifelse(
        treated == 1L,
        "Tarifgruppe",
        "Kontrollgruppe"
      ),
      levels = c("Kontrollgruppe", "Tarifgruppe")
    )
  ]

  if (is.null(recurring_share_threshold)) {
    tariff_band <- panel[
      treated == 1L,
      .(
        low_share = mean(signal_value == -1L, na.rm = TRUE),
        high_share = mean(signal_value == 1L, na.rm = TRUE)
      ),
      by = clock_time
    ]
    tariff_band[
      ,
      `:=`(
        state = data.table::fifelse(
          low_share >= high_share,
          "Niedrigtarif",
          "Hochtarif"
        ),
        state_share = pmax(low_share, high_share)
      )
    ]

    shading <- ggplot2::geom_rect(
      data = tariff_band,
      ggplot2::aes(
        xmin = clock_time - 0.125,
        xmax = clock_time + 0.125,
        ymin = -Inf,
        ymax = Inf,
        fill = state,
        alpha = state_share
      ),
      inherit.aes = FALSE
    )
    alpha_scale <- ggplot2::scale_alpha_continuous(
      range = c(0, 0.50),
      guide = "none"
    )
    fill_title <- "Häufigster aktiver Tarifzustand"
    caption <- paste0(
      "Die Farbintensität zeigt den Anteil der Tage in ", regime_label,
      ", an denen der jeweils häufigere aktive Tarifzustand galt."
    )
    diagnostic_data <- merge(
      profiles,
      tariff_band,
      by = "clock_time"
    )
  } else {
    zone_schedule <- unique(panel[
      treated == 1L &
        !is.na(free_grid) &
        !is.na(signal_value),
      .(free_grid, date, clock_time, signal_value)
    ])
    tariff_shares <- zone_schedule[
      ,
      .(
        low_share = mean(signal_value == -1L),
        high_share = mean(signal_value == 1L)
      ),
      by = clock_time
    ]
    tariff_band <- data.table::melt(
      tariff_shares,
      id.vars = "clock_time",
      variable.name = "state",
      value.name = "share"
    )
    tariff_band[
      ,
      state := data.table::fifelse(
        state == "low_share",
        "Niedrigtarif",
        "Hochtarif"
      )
    ]
    tariff_band <- tariff_band[share >= recurring_share_threshold]

    shading <- ggplot2::geom_rect(
      data = tariff_band,
      ggplot2::aes(
        xmin = clock_time - 0.125,
        xmax = clock_time + 0.125,
        ymin = -Inf,
        ymax = Inf,
        fill = state
      ),
      inherit.aes = FALSE,
      alpha = 0.35
    )
    alpha_scale <- NULL
    fill_title <- paste0(
      "Wiederkehrender Tarifzustand\n(\u2265 ",
      round(100 * recurring_share_threshold),
      " % der Zonen-Tage)"
    )
    caption <- paste0(
      "Die Hinterlegung markiert Tarifzustände, die zur jeweiligen ",
      "Viertelstunde an mindestens ",
      round(100 * recurring_share_threshold),
      " % der Zonen-Tage in ", regime_label, " aktiv waren."
    )
    diagnostic_data <- merge(
      profiles,
      tariff_shares,
      by = "clock_time"
    )
  }

  p <- ggplot2::ggplot() +
    shading +
    ggplot2::geom_line(
      data = profiles,
      ggplot2::aes(
        x = clock_time,
        y = mean_grid_withdrawal_kwh,
        color = arm,
        group = arm
      ),
      linewidth = 0.8
    ) +
    ggplot2::geom_point(
      data = profiles,
      ggplot2::aes(
        x = clock_time,
        y = mean_grid_withdrawal_kwh,
        color = arm
      ),
      size = 1.4
    ) +
    alpha_scale +
    ggplot2::scale_fill_manual(
      values = tariff_colors,
      name = fill_title
    ) +
    ggplot2::scale_color_manual(
      values = arm_colors,
      name = NULL
    ) +
    ggplot2::scale_x_continuous(
      breaks = seq(0, 24, by = 2),
      labels = sprintf("%02d", seq(0, 24, by = 2)),
      limits = c(0, 24)
    ) +
    ggplot2::labs(
      title = paste0(regime_label, ": mittlerer Netzbezug im Tagesverlauf"),
      x = "Tageszeit (Stunde)",
      y = "Mittlerer Netzbezug (kWh je 15 Minuten)",
      caption = caption
    ) +
    regime_theme

  save_figure(
    p,
    file.path(paths$output_figures, paste0(output_stem, ".png")),
    width = 8,
    height = 4.5
  )
  save_figure(
    p,
    file.path(paths$output_figures, paste0(output_stem, ".pdf")),
    width = 8,
    height = 4.5
  )
  data.table::fwrite(
    diagnostic_data,
    file.path(paths$output_diagnostics, paste0(output_stem, ".csv"))
  )

  invisible(p)
}

# ---------------------------------------------------------------------------
# Regime I: sparse forecast-based signals
# ---------------------------------------------------------------------------

regime_1 <- load_noe_regime(
  regime_dates$regime_1[1],
  regime_dates$regime_1[2]
)
create_sparse_regime_figure(
  regime_1,
  regime_label = "Regime I",
  output_stem = "report_fig06_regime1_tagesprofil"
)
rm(regime_1)
invisible(gc())

# ---------------------------------------------------------------------------
# Regime II: dense rotating signals
# ---------------------------------------------------------------------------

regime_2 <- load_noe_regime(
  regime_dates$regime_2[1],
  regime_dates$regime_2[2],
  include_rotation_group = TRUE
)

if (anyNA(regime_2$free_grid)) {
  stop("In Regime II fehlen Netzzonen.")
}

regime_2[, noe_group := as.integer(as.numeric(noe_group))]
if (
  !identical(sort(unique(regime_2$noe_group)), 0:2) ||
    anyNA(regime_2$noe_group)
) {
  stop("In Regime II müssen die Rotationsgruppen 0, 1 und 2 vorliegen.")
}

treated_states <- sort(unique(regime_2[treated == 1L, signal_value]))
if (!identical(treated_states, c(-1, 1))) {
  stop(
    "Tarifhaushalte dürfen in Regime II nur Niedrig- und Hochtarifsignale haben."
  )
}

schedule_check <- regime_2[
  treated == 1L,
  .(
    states = data.table::uniqueN(signal_value),
    scheduled_state = data.table::first(signal_value)
  ),
  by = .(free_grid, noe_group, time)
]
if (any(schedule_check$states != 1L)) {
  stop(
    "Die Signale sind innerhalb Netzzone x Rotationsgruppe x Zeitpunkt nicht einheitlich."
  )
}

schedule <- schedule_check[
  ,
  .(free_grid, noe_group, time, scheduled_state)
]
regime_2 <- schedule[
  regime_2,
  on = .(free_grid, noe_group, time)
]
if (anyNA(regime_2$scheduled_state)) {
  stop("Nicht allen Beobachtungen konnte ein Rotationssignal zugeordnet werden.")
}

regime_2[
  ,
  tariff_state := data.table::fifelse(
    treated == 1L,
    as.integer(signal_value),
    as.integer(scheduled_state)
  )
]
if (!all(regime_2$tariff_state %in% c(-1L, 1L))) {
  stop("Die Zuordnung der Tarifzustände in Regime II ist fehlgeschlagen.")
}

regime_2[
  ,
  `:=`(
    tariff_state = factor(
      data.table::fifelse(
        tariff_state == -1L,
        "Niedrigtarif",
        "Hochtarif"
      ),
      levels = c("Niedrigtarif", "Hochtarif")
    ),
    arm = factor(
      data.table::fifelse(
        treated == 1L,
        "Tarifgruppe",
        "Kontrollgruppe mit zugeordnetem Signal"
      ),
      levels = c(
        "Kontrollgruppe mit zugeordnetem Signal",
        "Tarifgruppe"
      )
    ),
    clock_slot = lubridate::hour(time) * 4L +
      lubridate::minute(time) %/% 15L
  )
]

household_profiles <- regime_2[
  ,
  .(mean_withdrawal_kwh = mean(cons_kwh_15m)),
  by = .(vzp_id, arm, tariff_state, clock_slot)
]
arm_profiles <- household_profiles[
  ,
  .(
    mean_withdrawal_kwh = mean(mean_withdrawal_kwh),
    households = .N,
    standard_error = stats::sd(mean_withdrawal_kwh) / sqrt(.N)
  ),
  by = .(arm, tariff_state, clock_slot)
]

treatment_profile <- arm_profiles[
  arm == "Tarifgruppe",
  .(
    tariff_state,
    clock_slot,
    treatment_mean = mean_withdrawal_kwh,
    treatment_se = standard_error,
    treatment_households = households
  )
]
control_profile <- arm_profiles[
  arm == "Kontrollgruppe mit zugeordnetem Signal",
  .(
    tariff_state,
    clock_slot,
    control_mean = mean_withdrawal_kwh,
    control_se = standard_error,
    control_households = households
  )
]

profile_contrast <- merge(
  treatment_profile,
  control_profile,
  by = c("tariff_state", "clock_slot")
)
profile_contrast[
  ,
  `:=`(
    hour_of_day = clock_slot / 4,
    mean_difference = treatment_mean - control_mean,
    standard_error = sqrt(treatment_se^2 + control_se^2)
  )
]
profile_contrast[
  ,
  `:=`(
    lower_95 = mean_difference - 1.96 * standard_error,
    upper_95 = mean_difference + 1.96 * standard_error
  )
]

sample_counts <- regime_2[
  ,
  .(
    households = data.table::uniqueN(vzp_id),
    household_days = data.table::uniqueN(paste(vzp_id, date)),
    observations = .N
  ),
  by = arm
]

p_regime_2 <- ggplot2::ggplot(
  profile_contrast,
  ggplot2::aes(
    x = hour_of_day,
    y = mean_difference
  )
) +
  ggplot2::geom_hline(
    yintercept = 0,
    color = "#7F7F7F",
    linetype = "dashed"
  ) +
  ggplot2::geom_ribbon(
    ggplot2::aes(ymin = lower_95, ymax = upper_95),
    fill = "#F2AD00",
    alpha = 0.18
  ) +
  ggplot2::geom_line(
    color = "#F2AD00",
    linewidth = 0.9
  ) +
  ggplot2::scale_x_continuous(
    breaks = seq(0, 24, by = 2),
    labels = sprintf("%02d", seq(0, 24, by = 2)),
    limits = c(0, 24)
  ) +
  ggplot2::facet_wrap(~tariff_state, nrow = 1) +
  ggplot2::labs(
    title = "Regime II: Differenz im Netzbezug nach Tarifzustand",
    x = "Tageszeit (Stunde)",
    y = "Differenz Tarif- minus Kontrollgruppe (kWh je 15 Minuten)",
    caption = paste0(
      "Regime II: 27. November 2025 bis 5. März 2026. Positive Werte ",
      "bedeuten einen höheren Netzbezug der Tarifgruppe.\n",
      "Haushaltsgewichtete deskriptive Mittelwerte; die Bänder zeigen ",
      "punktweise Konfidenzintervalle auf dem 95-%-Niveau."
    )
  ) +
  regime_theme

save_figure(
  p_regime_2,
  file.path(
    paths$output_figures,
    "report_fig07_regime2_tarifprofile.png"
  ),
  width = 8,
  height = 5.2
)
save_figure(
  p_regime_2,
  file.path(
    paths$output_figures,
    "report_fig07_regime2_tarifprofile.pdf"
  ),
  width = 8,
  height = 5.2
)

data.table::fwrite(
  sample_counts,
  file.path(
    paths$output_diagnostics,
    "report_fig07_regime2_stichprobe.csv"
  )
)
data.table::fwrite(
  arm_profiles,
  file.path(
    paths$output_diagnostics,
    "report_fig07_regime2_gruppenprofile.csv"
  )
)
data.table::fwrite(
  profile_contrast,
  file.path(
    paths$output_diagnostics,
    "report_fig07_regime2_differenzprofil.csv"
  )
)
saveRDS(
  list(
    sample_counts = sample_counts,
    arm_profiles = arm_profiles,
    profile_contrast = profile_contrast
  ),
  file.path(paths$output_models, "report_regime2_profiles.rds")
)

rm(
  regime_2,
  schedule_check,
  schedule,
  household_profiles,
  arm_profiles,
  treatment_profile,
  control_profile,
  profile_contrast,
  sample_counts,
  p_regime_2
)
invisible(gc())

# ---------------------------------------------------------------------------
# Regime III: return to sparse forecast-based signals
# ---------------------------------------------------------------------------

regime_3 <- load_noe_regime(
  regime_dates$regime_3[1],
  regime_dates$regime_3[2]
)
create_sparse_regime_figure(
  regime_3,
  regime_label = "Regime III",
  output_stem = "report_fig08_regime3_tagesprofil",
  recurring_share_threshold = 0.15
)
rm(regime_3)
invisible(gc())

message("04_report_tariff_regimes.R completed successfully.")
