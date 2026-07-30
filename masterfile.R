###############################################################################
# masterfile.R
#
# Purpose:
# Generate the report figures and tables from the final processed panel_15m
# dataset. No raw loading/cleaning here - see innonet-tariff-analysis for that.
###############################################################################

rm(list = ls())
gc()

message("Starting masterfile...")

source("R/01_report_figures.R")
source("R/02_parallel_trends.R")
source("R/03_tariff_window_tables.R")

message("Masterfile finished successfully.")
