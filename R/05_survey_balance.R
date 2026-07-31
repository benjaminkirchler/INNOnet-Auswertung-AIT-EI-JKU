###############################################################################
# 05_survey_balance.R
#
# Purpose:
# Create survey-based equipment balance tables for NOE and LN and test whether
# treatment assignment is jointly associated with observed household traits.
# LN static and dynamic tariff arms are pooled into one treatment group.
###############################################################################

rm(list = ls())
gc()

message("Running 05_survey_balance.R ...")

invisible(lapply(
  c("dplyr", "tidyr", "readr", "tableone", "kableExtra"),
  library,
  character.only = TRUE
))

table_dir <- here::here("paper", "tables")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

# The shared report repository contains only anonymised aggregate outputs. The
# household-level survey input stays local. It can either be placed in the same
# relative data paths as below or read from the sibling analysis repository.
analysis_root <- Sys.getenv("INNONET_ANALYSIS_DIR", unset = "")
if (!nzchar(analysis_root)) {
  local_survey <- here::here("data", "processed", "survey_clean.rds")
  if (file.exists(local_survey)) {
    analysis_root <- here::here()
  } else {
    analysis_root <- normalizePath(
      here::here("..", "..", "innonet-tariff-analysis"),
      winslash = "/", mustWork = TRUE
    )
  }
}

survey_path <- file.path(analysis_root, "data", "processed", "survey_clean.rds")
household_path <- file.path(
  analysis_root, "data", "processed", "roman_final", "household_master.rds"
)
stopifnot(file.exists(survey_path), file.exists(household_path))

households <- readRDS(household_path) |>
  dplyr::select(vzp_id, grid_operator, treated, group_label) |>
  dplyr::mutate(vzp_id = as.character(vzp_id))

survey <- readRDS(survey_path) |>
  dplyr::transmute(
    vzp_id = as.character(vzp_id),
    pv_status = dplyr::case_when(
      has_pv_raw == "Nein" ~ "Keine PV",
      has_pv_raw == "Ja, eine Photovoltaik-Anlage" ~ "PV ohne Speicher",
      has_pv_raw == "Ja, eine Photovoltaik-Anlage mit Speicher" ~ "PV mit Speicher",
      TRUE ~ "Keine Angabe"
    ),
    pv_capacity = dplyr::case_when(
      has_pv_raw == "Nein" ~ "Keine PV",
      pv_capacity_raw == "Weniger als 5 kWpeak" ~ "Unter 5 kWp",
      pv_capacity_raw == "Zwischen 5 kWpeak und 10 kWpeak" ~ "5 bis 10 kWp",
      pv_capacity_raw == "Mehr als 10 kWpeak" ~ "Über 10 kWp",
      pv_capacity_raw == "Das weiß ich nicht" ~ "Unbekannt",
      TRUE ~ "Keine Angabe"
    ),
    ev_status = dplyr::if_else(has_ev == 1L, "E-Fahrzeug", "Kein E-Fahrzeug"),
    ev_charging = dplyr::case_when(
      has_ev != 1L ~ "Kein E-Fahrzeug",
      grepl("Wallbox", ev_charging_type, fixed = TRUE) ~ "Eigene Wallbox",
      grepl("normalen Steckdose", ev_charging_type, fixed = TRUE) ~ "Normale Steckdose",
      ev_charging_type == "Am Arbeitsplatz" ~ "Am Arbeitsplatz",
      ev_charging_type == "An öffentlichen Ladestationen" ~ "Öffentliche Ladestation",
      TRUE ~ "Keine Angabe"
    ),
    dwelling_size_m2 = as.numeric(dwelling_size_m2),
    household_size = dplyr::case_when(
      household_size_raw == "Mehr als 5 Personen" ~ 6,
      TRUE ~ as.numeric(household_size)
    ),
    ownership = dplyr::case_when(
      ownership_status == "Eigentum oder Eigentum eines Haushaltsmitglieds" ~ "Eigentum",
      ownership_status == "Miete" ~ "Miete",
      TRUE ~ "Keine Angabe"
    ),
    children_u14 = dplyr::case_when(
      children_u14_raw == "" | is.na(children_u14_raw) ~ "Keine Angabe",
      children_u14_raw == "Keine" ~ "Nein",
      TRUE ~ "Ja"
    ),
    income = dplyr::case_when(
      income_category == "" | is.na(income_category) ~ "Keine Angabe",
      TRUE ~ income_category
    )
  )

balance_data <- households |>
  dplyr::left_join(survey, by = "vzp_id") |>
  dplyr::filter(!is.na(pv_status)) |>
  dplyr::mutate(
    treatment = as.integer(treated == 1L),
    treatment_group = factor(
      treatment, levels = c(0, 1), labels = c("Kontrollgruppe", "Treatment")
    ),
    pv_status = factor(
      pv_status,
      levels = c("Keine PV", "PV ohne Speicher", "PV mit Speicher", "Keine Angabe")
    ),
    pv_capacity = factor(
      pv_capacity,
      levels = c(
        "Keine PV", "Unter 5 kWp", "5 bis 10 kWp", "Über 10 kWp",
        "Unbekannt", "Keine Angabe"
      )
    ),
    ev_status = factor(ev_status, levels = c("Kein E-Fahrzeug", "E-Fahrzeug")),
    ev_charging = factor(
      ev_charging,
      levels = c(
        "Kein E-Fahrzeug", "Eigene Wallbox", "Normale Steckdose",
        "Am Arbeitsplatz", "Öffentliche Ladestation", "Keine Angabe"
      )
    ),
    ownership = factor(ownership, levels = c("Eigentum", "Miete", "Keine Angabe")),
    children_u14 = factor(children_u14, levels = c("Nein", "Ja", "Keine Angabe")),
    income = factor(
      income,
      levels = c(
        "bis zu 1.500 Euro", "1.501 bis 2.500 Euro", "2.501 bis 3.500 Euro",
        "3.501 bis 4.500 Euro", "4.501 bis 5.500 Euro", "über 5.500 Euro",
        "Keine Angabe"
      )
    )
  )

factor_vars <- c(
  "pv_status", "pv_capacity", "ev_status", "ev_charging",
  "ownership", "children_u14", "income"
)
numeric_vars <- c("dwelling_size_m2", "household_size")
balance_vars <- c(factor_vars, numeric_vars)

# Verify that every displayed categorical distribution is exhaustive. Because
# non-response is an explicit level, the percentages must sum to exactly 100%
# within every operator-treatment cell before rounding.
percentage_checks <- balance_data |>
  dplyr::select(grid_operator, treatment_group, dplyr::all_of(factor_vars)) |>
  tidyr::pivot_longer(
    cols = dplyr::all_of(factor_vars),
    names_to = "variable", values_to = "level"
  ) |>
  dplyr::count(grid_operator, treatment_group, variable, level, .drop = FALSE) |>
  dplyr::group_by(grid_operator, treatment_group, variable) |>
  dplyr::mutate(percent = 100 * n / sum(n)) |>
  dplyr::summarise(percent_sum = sum(percent), .groups = "drop")

stopifnot(all(abs(percentage_checks$percent_sum - 100) < 1e-10))
readr::write_csv(
  percentage_checks,
  file.path(table_dir, "survey_balance_percentage_checks.csv")
)

variable_labels <- c(
  pv_status = "PV-Ausstattung (Survey)",
  pv_capacity = "PV-Leistung (Survey)",
  ev_status = "E-Fahrzeug",
  ev_charging = "Ladeort des E-Fahrzeugs",
  dwelling_size_m2 = "Wohnfläche (m2)",
  household_size = "Haushaltsgröße (Personen)",
  ownership = "Eigentumsverhältnis",
  children_u14 = "Kinder unter 14 Jahren",
  income = "Monatliches Netto-Haushaltseinkommen"
)

make_tableone <- function(data, operator, filename, caption, label) {
  operator_data <- data |>
    dplyr::filter(grid_operator == operator) |>
    dplyr::rename(!!!stats::setNames(names(variable_labels), variable_labels))

  labelled_vars <- unname(variable_labels)
  labelled_factor_vars <- unname(variable_labels[factor_vars])

  tab <- tableone::CreateTableOne(
    vars = labelled_vars,
    strata = "treatment_group",
    data = operator_data,
    factorVars = labelled_factor_vars,
    test = TRUE,
    smd = TRUE,
    addOverall = FALSE
  )

  tab_matrix <- print(
    tab,
    showAllLevels = TRUE,
    quote = FALSE,
    noSpaces = TRUE,
    printToggle = FALSE,
    test = TRUE,
    smd = TRUE,
    missing = TRUE
  )
  tab_df <- data.frame(Merkmal = rownames(tab_matrix), tab_matrix, check.names = FALSE)
  rownames(tab_df) <- NULL
  tab_df$Merkmal <- gsub(
    "(mean (SD))", "(Mittelwert (SD))", tab_df$Merkmal, fixed = TRUE
  )
  tab_df$Merkmal[tab_df$Merkmal == "n"] <- "N"
  tab_df <- tab_df |>
    dplyr::transmute(
      Merkmal,
      Ausprägung = level,
      Kontrollgruppe,
      Treatment,
      `p-Wert` = p,
      SMD
    )

  writeLines(
    as.character(
      kableExtra::kbl(
        tab_df,
        format = "latex",
        booktabs = TRUE,
        escape = TRUE,
        caption = caption,
        label = label,
        linesep = ""
      ) |>
        kableExtra::kable_styling(
          latex_options = c("hold_position", "scale_down"),
          font_size = 8
        )
    ),
    file.path(table_dir, filename)
  )

  readr::write_csv(tab_df, file.path(table_dir, sub("\\.tex$", ".csv", filename)))
  invisible(tab)
}

table_ln <- make_tableone(
  balance_data,
  "LN",
  "survey_equipment_balance_ln.tex",
  paste0(
    "Ausstattungs- und Haushaltsbalance in Linz Netz. Dynamischer und ",
    "statischer Tarifarm sind als Treatment zusammengefasst. Kategoriale ",
    "Variablen werden als Anzahl (Prozent), kontinuierliche Variablen als ",
    "Mittelwert (Standardabweichung) dargestellt. PV-Angaben stammen aus ",
    "dem Rekrutierungssurvey."
  ),
  "survey_equipment_balance_ln"
)

table_noe <- make_tableone(
  balance_data,
  "NOE",
  "survey_equipment_balance_noe.tex",
  paste0(
    "Ausstattungs- und Haushaltsbalance in Netz Oberösterreich. Kategoriale ",
    "Variablen werden als Anzahl (Prozent), kontinuierliche Variablen als ",
    "Mittelwert (Standardabweichung) dargestellt. PV-Angaben stammen aus ",
    "dem Rekrutierungssurvey."
  ),
  "survey_equipment_balance_noe"
)

# Logistic assignment models. Storage status and PV-capacity midpoint capture
# the survey PV strata without using the EZP/panel PV flag. EV and wallbox are
# entered separately; explicit missing indicators retain all matched surveys.
regression_data <- balance_data |>
  dplyr::mutate(
    pv_storage = as.integer(pv_status == "PV mit Speicher"),
    pv_without_storage = as.integer(pv_status == "PV ohne Speicher"),
    pv_capacity_mid = dplyr::case_when(
      pv_capacity == "Keine PV" ~ 0,
      pv_capacity == "Unter 5 kWp" ~ 2.5,
      pv_capacity == "5 bis 10 kWp" ~ 7.5,
      pv_capacity == "Über 10 kWp" ~ 12.5,
      TRUE ~ 0
    ),
    has_ev = as.integer(ev_status == "E-Fahrzeug"),
    charges_wallbox = as.integer(ev_charging == "Eigene Wallbox"),
    owner = as.integer(ownership == "Eigentum"),
    has_children_u14 = as.integer(children_u14 == "Ja"),
    children_missing = as.integer(children_u14 == "Keine Angabe"),
    income_group = factor(
      dplyr::case_when(
        income %in% c(
          "bis zu 1.500 Euro", "1.501 bis 2.500 Euro", "2.501 bis 3.500 Euro"
        ) ~ "Bis 3.500 Euro",
        income %in% c("3.501 bis 4.500 Euro", "4.501 bis 5.500 Euro") ~
          "3.501 bis 5.500 Euro",
        income == "über 5.500 Euro" ~ "Über 5.500 Euro",
        TRUE ~ "Keine Angabe"
      ),
      levels = c(
        "Bis 3.500 Euro", "3.501 bis 5.500 Euro", "Über 5.500 Euro",
        "Keine Angabe"
      )
    )
  )

assignment_formula <- treatment ~
  pv_without_storage + pv_storage + pv_capacity_mid +
  has_ev + charges_wallbox + dwelling_size_m2 + household_size + owner +
  has_children_u14 + children_missing + income_group

fit_assignment_model <- function(data, operator) {
  model_data <- data |>
    dplyr::filter(grid_operator == operator)
  model <- stats::glm(
    assignment_formula,
    data = model_data,
    family = stats::binomial(link = "logit")
  )
  null_model <- stats::glm(
    treatment ~ 1,
    data = model_data,
    family = stats::binomial(link = "logit")
  )

  coefs <- summary(model)$coefficients
  ci <- stats::confint.default(model)
  ci <- ci[rownames(coefs), , drop = FALSE]
  coef_table <- data.frame(
    operator = operator,
    term = rownames(coefs),
    odds_ratio = exp(coefs[, "Estimate"]),
    ci_low = exp(ci[, 1]),
    ci_high = exp(ci[, 2]),
    p_value = coefs[, "Pr(>|z|)"],
    row.names = NULL
  )

  lr <- stats::anova(null_model, model, test = "Chisq")
  model_test <- data.frame(
    operator = operator,
    n = stats::nobs(model),
    likelihood_ratio_chisq = lr$Deviance[2],
    df = lr$Df[2],
    p_value = lr$`Pr(>Chi)`[2],
    mcfadden_r2 = 1 - as.numeric(stats::logLik(model) / stats::logLik(null_model))
  )

  list(model = model, coefficients = coef_table, test = model_test)
}

model_ln <- fit_assignment_model(regression_data, "LN")
model_noe <- fit_assignment_model(regression_data, "NOE")

coefficient_table <- dplyr::bind_rows(
  model_ln$coefficients,
  model_noe$coefficients
)
model_test_table <- dplyr::bind_rows(model_ln$test, model_noe$test)

readr::write_csv(
  coefficient_table,
  file.path(table_dir, "survey_assignment_logit_coefficients.csv")
)
readr::write_csv(
  model_test_table,
  file.path(table_dir, "survey_assignment_logit_joint_tests.csv")
)

regression_display <- coefficient_table |>
  dplyr::filter(term != "(Intercept)") |>
  dplyr::mutate(
    Netzgebiet = dplyr::recode(operator, LN = "Linz Netz", NOE = "Netz Oberösterreich"),
    Merkmal = dplyr::recode(
      term,
      pv_without_storage = "PV ohne Speicher (vs. keine PV)",
      pv_storage = "PV mit Speicher (vs. keine PV)",
      pv_capacity_mid = "PV-Leistung (kWp; Kategorienmittelpunkt)",
      has_ev = "E-Fahrzeug",
      charges_wallbox = "Laden an eigener Wallbox",
      dwelling_size_m2 = "Wohnfläche (m2)",
      household_size = "Haushaltsgröße (Personen)",
      owner = "Eigentum",
      has_children_u14 = "Kinder unter 14 Jahren",
      children_missing = "Kinderangabe fehlt",
      `income_group3.501 bis 5.500 Euro` = "Einkommen 3.501 bis 5.500 Euro",
      `income_groupÜber 5.500 Euro` = "Einkommen über 5.500 Euro",
      `income_groupKeine Angabe` = "Einkommen: keine Angabe",
      .default = term
    ),
    `Odds Ratio (95%-KI)` = sprintf("%.2f [%.2f; %.2f]", odds_ratio, ci_low, ci_high),
    `p-Wert` = sprintf("%.3f", p_value)
  ) |>
  dplyr::select(Netzgebiet, Merkmal, `Odds Ratio (95%-KI)`, `p-Wert`)

writeLines(
  as.character(
    kableExtra::kbl(
      regression_display,
      format = "latex",
      booktabs = TRUE,
      escape = TRUE,
      caption = paste0(
        "Logistische Regression der Treatmentzuordnung auf beobachtbare ",
        "Survey-Merkmale, getrennt nach Netzgebiet. Angegeben sind Odds Ratios ",
        "mit 95\\%-Konfidenzintervallen und zweiseitigen p-Werten."
      ),
      label = "survey_assignment_logit",
      linesep = ""
    ) |>
      kableExtra::kable_styling(
        latex_options = c("hold_position", "scale_down"),
        font_size = 8
      )
  ),
  file.path(table_dir, "survey_assignment_logit.tex")
)

print(percentage_checks)
print(model_test_table)
message("05_survey_balance.R completed successfully.")
