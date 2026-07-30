# CLAUDE.md

Project guidance for AI agents (Claude, Codex, others) working in this repository.
This template is for one empirical/behavioral economics research project. GitHub is the source of truth; Overleaf and OSF are interfaces, not primary storage.

## Hard rules

- Never edit anything in `data/raw/`.
- Never invent, estimate, or "fill in" numerical results. All numbers in the manuscript come from generated outputs in `paper/tables/` and `paper/figures/`, or from R objects.
- All stochastic steps (simulation, randomization, bootstrap) use the explicit seed defined once in `R/00_setup.R`.
- The full pipeline must always run from a clean session via `source("masterfile.R")`.
- Do not commit credentials, OSF tokens, or personally identifiable data.

## Plan adherence

The user sometimes loses track of the plan. Do not silently follow a request that deviates from the planned next step.

- The active plan lives in `IMPLEMENTATION_PLAN.md`, `TODO.md`, and any preregistration in `prestudy/`/`OSF/`.
- If a request deviates from the current planned step, ask first:
  "The plan's next step is **<planned>**, but you're asking for **<requested>**. Do you really want to switch, or continue with the plan?"
- Proceed with the deviation only on an explicit "yes". Otherwise continue as planned.
- Small clarifications and fixes are exempt — this is only for real changes of direction or skipping steps.

## Teach the user, don't let them follow blindly

The user is a PhD student who wants to learn from each project. Follow the `mentor-and-learning` skill:
- Explain non-trivial methodological and modeling choices in plain terms before acting.
- Ask a short question to check understanding of new/subtle concepts; teach on gaps.
- Occasionally pose a quick conceptual knowledge check.
- When useful domain knowledge or a decision rationale comes up, offer to record it in `internal/`.

## Logging and to-do workflow

Follow the `project-log-and-todo` skill:
- Read `AGENT_LOG.md` and `TODO.md` at the start of a session; summarize last work and next steps.
- Append a structured entry to `AGENT_LOG.md` for each meaningful action.
- Keep `TODO.md` (the human-readable list) current; it is the plain-language translation of the log.
- Regenerate the Overleaf annex with `source("R/99_generate_todo_annex.R")` at session end.

## Model routing

| Task type | Recommended model | Why |
|-----------|-------------------|-----|
| Theory & proofs, identification arguments, referee responses, research design | Most capable (Opus / Fable class) | Errors are subtle and expensive |
| Drafting new manuscript sections, causal-inference analysis code | Capable (Opus or Sonnet) | Needs judgment but is more structured |
| Routine R edits, table/figure formatting, bib cleanup, refactoring, README updates | Sonnet class | Mechanical but non-trivial |
| Renames, file moves, search, simple find-and-fix | Haiku class or Explore agent | Low-judgment, high-volume |

When in doubt about a judgment-heavy task, escalate to the stronger model.

## Skills (in `.claude/skills/`)

- `research-r-pipeline` — the staged R pipeline, packages, reproducibility, verification checklist.
- `causal-inference` — estimator choice, mandatory checks, reporting for DiD/SDID/RCT/IV/RDD.
- `theory-modeling` — reference-dependent and threshold-provision models, notation, proofs, numerical checks.
- `economics-paper-writing` — contribution-first writing; section templates in `references/`.
- `latex-paper-workflow` — editing `paper/` and syncing R outputs into the manuscript.
- `osf-preregistration` — preregistration, power analysis, OSF uploads.
- `multi-agent-research-collaboration` — splitting work across Claude/Codex without conflicts.
- `mentor-and-learning` — teaching and knowledge checks.
- `project-log-and-todo` — the agent log, to-do list, Overleaf annex, and plan adherence.

## Key commands

- Full analysis: `source("masterfile.R")`
- Pre-study/preregistration: `source("prestudy/masterfile_prestudy.R")`
- Regenerate to-do annex: `source("R/99_generate_todo_annex.R")`
- Compile paper: `latexmk -pdf paper/main.tex`
