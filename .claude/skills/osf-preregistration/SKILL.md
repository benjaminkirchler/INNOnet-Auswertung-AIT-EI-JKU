---
name: OSF Preregistration
description: Work with OSF and preregistration materials in this research template. Use when preparing OSF uploads, preregistration text, pre-analysis plans, power analysis, randomization templates, or documentation for reproducible research.
---

# OSF Preregistration

## Project Structure

Relevant folders:

- `OSF/` contains OSF-related documentation.
- `OSF/preregistration/` contains preregistration materials.
- `prestudy/paper/` contains LaTeX preregistration text.
- `prestudy/R/` contains power simulation and randomization templates.
- `prestudy/masterfile_prestudy.R` runs the prestudy workflow.

## Instructions

1. Keep preregistration claims aligned with the actual planned analysis scripts.
2. When editing preregistration text, check the matching analysis plan in `prestudy/R/`.
3. Make power-analysis assumptions explicit: effect size, sample size, alpha level, simulation count, and random seed.
4. Distinguish planned analyses from exploratory analyses.
5. Prepare OSF-facing documentation with clear file names and short descriptions.
6. Do not place private credentials, OSF tokens, or unpublished sensitive data in the repository.

## Output Expectations

- Preregistration text should be precise enough to audit later.
- OSF upload checklists should identify which files belong on OSF and which should stay local.
- Any changes to planned analyses should also mention whether corresponding paper/prestudy text needs updating.

