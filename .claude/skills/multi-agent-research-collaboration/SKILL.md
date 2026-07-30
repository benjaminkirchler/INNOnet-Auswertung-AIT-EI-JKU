---
name: Multi-Agent Research Collaboration
description: Coordinate Claude Code, Codex, and other agents working on the same research project through ClaudeR, GitHub, or RStudio. Use when splitting analysis, reviewing another agent's edits, or avoiding conflicts in shared project files.
---

# Multi-Agent Research Collaboration

## Instructions

1. Assume another agent may be working in the same repository or RStudio session.
2. Before editing, inspect the relevant file and recent context.
3. State file ownership when splitting work. For example: one agent handles `R/04_analysis.R`, another reviews `paper/sections/05_empirical_strategy.tex`.
4. Do not overwrite another agent's changes unless the user explicitly asks.
5. Prefer review and verification tasks when another agent has just produced code.
6. Mention exact files changed, objects created, and commands run so another agent can continue.

## Good Task Splits

- Codex writes or runs R code; Claude Code reviews reproducibility and manuscript consistency.
- Claude Code drafts preregistration text; Codex checks that the R scripts implement the plan.
- One agent creates figures; the other checks manuscript references to those figures.
- One agent updates OSF documentation; the other checks that sensitive files are not included.

## Review Checklist

- Does `masterfile.R` still run from a clean session?
- Are raw data files untouched?
- Are tables and figures generated into the expected folders?
- Do manuscript claims match R outputs?
- Are generated files, private data, and OSF materials handled intentionally?

