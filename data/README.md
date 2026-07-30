# Data Codebook

Every dataset in `data/processed/` needs a codebook entry below. One variable per row.
Keep this file up to date whenever `R/02_cleaning.R` changes the analysis data.

## `analysis_data.csv`

| Variable | Type | Description | Source | Units | Notes |
|----------|------|-------------|--------|-------|-------|
| id | integer | Unit identifier | raw data | — | Unique per unit |
| treatment | factor | Treatment group indicator | assignment | 0/1 | Level of randomization |
| outcome | numeric | Primary outcome | raw data | — | Define units explicitly |

## Folder policy

- `data/raw/` — original data, read-only, never committed (except `.keep`).
- `data/interim/` — intermediate objects, not committed.
- `data/processed/` — cleaned analysis-ready data.
- `data/simulated/` — simulated/demonstration data.
- `data/final/` — final exports, not committed.

Do not commit confidential, proprietary, or personally identifiable data.
