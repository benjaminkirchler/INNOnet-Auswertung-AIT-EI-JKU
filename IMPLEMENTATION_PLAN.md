# Implementation Plan: Template Improvements

**Audience:** an implementing AI agent (or human). This file contains complete, self-contained instructions. Do not invent content beyond what is specified here; where wording is left open, follow the style of the existing skills in `.claude/skills/`.

**Context:** This repo is a template for empirical/behavioral economics research projects (R pipeline + LaTeX paper + OSF preregistration). The user is a PhD student in economics (WU Wien) working on quasi-experimental energy/behavioral papers (DiD, SDID, Poisson fixed effects, RCTs) and applied theory (Kőszegi–Rabin reference-dependent preferences, Zubrickas-style threshold crowdfunding).

**General rules for the implementer:**
- Match the tone and format of existing skills: short imperative sentences, `##` headers, numbered instruction lists, no fluff.
- Every new skill lives in `.claude/skills/<skill-name>/SKILL.md` with YAML frontmatter containing `name:` and `description:`. The `description` must state *when to use* the skill (this drives triggering).
- Do not modify `data/`, `masterfile.R` pipeline logic, or existing paper content.
- After each task, verify the file exists and the frontmatter parses (no tabs, `---` fences).

---

## Task 1: Create `CLAUDE.md` at the repo root

This is the highest-priority task. The file is always loaded into context, unlike skills.

Content, in this order:

1. **Project overview** (3–4 lines): what the template is, "one repository = one research project", GitHub is source of truth; Overleaf and OSF are interfaces.
2. **Hard rules** (bullet list, verbatim):
   - Never edit anything in `data/raw/`.
   - Never invent, estimate, or "fill in" numerical results. All numbers in the manuscript come from generated outputs in `paper/tables/` and `paper/figures/` or from R objects.
   - All stochastic steps (simulation, randomization, bootstrap) set an explicit seed defined once in `R/00_setup.R`.
   - The full pipeline must always run from a clean session via `source("masterfile.R")`.
   - Do not commit credentials, OSF tokens, or personally identifiable data.
3. **Model routing table** (markdown table). Columns: Task type | Recommended model | Why. Rows:
   - Theory/proofs, identification arguments, referee responses, research design → most capable model (Opus/Fable class) — errors are expensive and subtle.
   - Drafting new manuscript sections, causal-inference analysis code → capable model (Opus or Sonnet).
   - Routine R edits, table/figure formatting, bib cleanup, refactoring, README updates → Sonnet class.
   - Renames, file moves, search tasks, simple find-and-fix → Haiku class or Explore agent.
   Add one line: "When in doubt about a judgment-heavy task, escalate to the stronger model."
4. **Skill map** (one line per skill in `.claude/skills/`, saying when to invoke it). Include the new skills from Tasks 2–3.
5. **Key commands**: `source("masterfile.R")`, `source("prestudy/masterfile_prestudy.R")`, LaTeX compile via `latexmk -pdf paper/main.tex`.

Acceptance: file under ~120 lines; no duplication of full skill content (link, don't copy).

## Task 2: New skill `.claude/skills/causal-inference/SKILL.md`

Frontmatter description: "Design, implement, or review causal-inference analyses (DiD, event studies, synthetic DiD, RCTs, IV, RDD) in this template's R pipeline. Use when writing `R/04_analysis.R`, choosing estimators, specifying fixed effects, clustering, robustness checks, or interpreting treatment effects."

Sections and required content:

### Estimator choice
- Two-period or uniform-timing DiD: `fixest::feols` with explicit unit and time fixed effects.
- Staggered adoption: do NOT use plain two-way fixed effects; use Callaway–Sant'Anna (`did` package) or Sun–Abraham (`fixest::sunab`) and state the comparison group.
- Few treated units / aggregate policy: synthetic DiD (`synthdid`) or synthetic control; report placebo-based inference.
- Count outcomes: Poisson pseudo-maximum-likelihood (`fixest::fepois`), not log-linear OLS; note this handles zeros and is robust under correct conditional mean.
- RCT: ANCOVA specification (outcome on treatment + baseline outcome) preferred over difference-in-means or change scores.

### Mandatory checks (numbered list)
1. Plot raw outcome means by group over time before any regression.
2. Event-study/pre-trend plot for any DiD claim; report joint test of pre-period coefficients.
3. Justify the clustering level in a comment (cluster at the level of treatment assignment); if few clusters (<40), use wild cluster bootstrap (`fwildclusterboot`) or randomization inference.
4. At least one placebo test (fake treatment date or fake treated group).
5. Report the number of units, clusters, and observations in every table.

### Reporting
- Always report economic magnitudes (percent effects, effects relative to control mean), not only coefficients and stars.
- Every headline estimate gets both a table row and, where dynamics matter, an event-study figure.
- State the identifying assumption in one sentence near the main result and say what evidence supports it.

### Known project-specific pitfalls (verbatim, these come from the user's real projects)
- Zeros in billing/consumption data may reflect billing censoring, not true zero consumption — investigate before treating as outcomes.
- Heating-fuel or infrastructure differences can confound regional treatment comparisons — check covariate balance across regions.
- With large data, load selectively (Arrow/parquet, column selection) to stay RAM-lean.

## Task 3: New skill `.claude/skills/theory-modeling/SKILL.md`

Frontmatter description: "Develop, check, or write up economic theory models — reference-dependent preferences (Kőszegi–Rabin), threshold public goods / crowdfunding (Zubrickas), identity, and behavioral mechanisms. Use when writing model sections, propositions, proofs, or numerical verification code."

Sections and required content:

### Notation conventions
- Kőszegi–Rabin models: η is the weight on gain–loss utility, λ > 1 is loss aversion; state the reference-point concept used (CPE, UPE, or lagged expectations) explicitly at the start of the model section.
- Define every symbol at first use; maintain one notation table in the paper's design/appendix folder.
- Keep notation consistent between the note/derivation file and the paper section — if one changes, update the other in the same session.

### Model development workflow (numbered)
1. Write the economic environment first: players, actions, timing, information, payoffs.
2. State each result as a numbered Proposition with explicit assumptions.
3. Proof structure: claim → proof → one-paragraph economic intuition after the proof.
4. Every proposition and every comparative static must be verified with a numerical example in R (a standalone script, seeded, that checks the claimed inequality/sign over a parameter grid). Save these scripts alongside the theory files.
5. End the model section with testable predictions, each mapped to an empirical specification or treatment comparison.

### Writing style for theory
- Prose explains economics; math states results. No unexplained algebra walls — long derivations go to an appendix.
- Flag any assumption made purely for tractability and say what it rules out.

## Task 4: New reference files under `.claude/skills/economics-paper-writing/references/`

Do not create new skills for individual sections. Add reference files (markdown, each ≤ ~80 lines) and add one line to the existing `economics-paper-writing/SKILL.md` pointing to each ("For X, read `references/<file>.md`"):

1. `introduction-formula.md` — a paragraph-by-paragraph introduction template: (1) hook: the concrete question and why it matters, ≤2 sentences of motivation; (2) what this paper does: setting, design, data in plain words; (3) main findings with magnitudes; (4) mechanism/interpretation; (5) contribution relative to the 3–5 closest papers; (6) optional roadmap only if the structure is nonstandard.
2. `results-section.md` — order: main result first; one table/figure per claim; interpret magnitude before significance; robustness compressed into one subsection or appendix pointer; never narrate tables cell by cell.
3. `referee-response.md` — R&R response letter conventions: thank briefly and once; number every reviewer point verbatim in italics/quote, respond directly below; every response says what changed and where (section/page); disagree politely with evidence, never dismissively; keep a summary-of-changes page for the editor; never claim a change that was not actually made in the manuscript.
4. `abstract-checklist.md` — ≤150 words target; first sentence states what the paper finds; includes design and data only as needed; ends with the contribution or implication; no citations, no "we discuss".

## Task 5: Expand `.claude/skills/research-r-pipeline/SKILL.md`

Append these sections (keep everything already in the file):

### Packages and conventions
- Fixed effects estimation: `fixest`. Regression tables: `modelsummary` (export `.tex` to `paper/tables/`); never hand-type numbers into LaTeX tables.
- Paths: `here::here()` everywhere; never `setwd()` or absolute paths.
- One global seed constant defined in `R/00_setup.R`; every stochastic step references it.
- Large data: prefer `arrow`/parquet with column selection over reading full CSVs.
- Figures: `ggplot2`, saved via a single `save_figure()` helper (define it in `R/00_setup.R`: wraps `ggsave` with fixed width/height/dpi) so all figures share dimensions.

### Reproducibility
- Initialize `renv` in each cloned project (`renv::init()`, commit `renv.lock`). Add a line to the root `README.md` Step 1 instructions saying to run `renv::init()` after cloning.
- `sessionInfo()` output is written to `output/logs/` at the end of `masterfile.R` — add this line to `masterfile.R` if not present: `writeLines(capture.output(sessionInfo()), "output/logs/sessionInfo.txt")`.

### Post-change verification checklist (numbered)
1. Rerun the edited stage script in a clean session.
2. Rerun `source("masterfile.R")` fully.
3. Diff the regenerated files in `paper/tables/` and `paper/figures/`.
4. If any output changed, grep `paper/sections/` for the affected numbers and update the manuscript text.

## Task 6: Housekeeping

1. Add to `.gitignore`: `.RData`, `.Rhistory`, `*.Rproj.user/`, and standard LaTeX build artifacts (`*.aux`, `*.log`, `*.out`, `*.bbl`, `*.blg`, `*.synctex.gz`, `*.fls`, `*.fdb_latexmk`). Then `git rm --cached .RData .Rhistory` if the repo is git-tracked.
2. Create `data/README.md`: a codebook template with a table (columns: variable | type | description | source | units | notes) plus a short header explaining that every dataset in `data/processed/` needs a codebook entry.
3. Create `.claude/settings.json` with a permission allowlist for common safe commands (Rscript, git status/diff/log/add/commit, latexmk). Use the standard Claude Code settings schema (`permissions.allow` array with entries like `"Bash(git status:*)"`, `"Bash(Rscript:*)"`, `"Bash(latexmk:*)"`).
4. In `README.md`, add a short "Revisions" subsection under Typical Workflow: for R&R, create `revision/round_<n>/` containing `response_letter.tex` and a `changes.md` tracking each reviewer point → change → location. (Create an empty `revision/.keep` too.)
5. Update the Skill map in `CLAUDE.md` (Task 1) to include the new skills — do Task 1 last or revisit it.

## Verification (run at the end)

- All new files exist at the specified paths; frontmatter of each SKILL.md is valid YAML between `---` fences.
- `CLAUDE.md` mentions every skill folder present in `.claude/skills/`.
- No file in `data/`, `R/` (except none required), or `paper/sections/` was modified other than specified.
- `README.md` changes are limited to the renv line and the Revisions subsection.
