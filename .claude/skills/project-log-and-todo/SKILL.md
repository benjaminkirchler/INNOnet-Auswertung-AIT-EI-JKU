---
name: Project Log and To-Do
description: Maintain the shared agent log, the human-readable to-do list, and the Overleaf to-do annex; and enforce plan adherence. Use at the start and end of any work session, when multiple agents (Claude, Codex) share the repo, or before deviating from the plan.
---

# Project Log and To-Do

This project keeps three linked artifacts:

- `AGENT_LOG.md` — append-only, machine-oriented log. Every agent (Claude, Codex, others) writes here.
- `TODO.md` — human-readable to-do list, the single source of truth for tasks (section, id, task, priority, status). This is what the user reads.
- `paper/sections/99_todo_annex.tex` — a colored to-do table generated from `TODO.md`, loaded as an appendix so the user sees status inside the compiled Overleaf PDF.

## At the start of a session

1. Read `AGENT_LOG.md` (recent entries) and `TODO.md`.
2. Summarize for the user, in plain language, what was done last and what the next planned steps are.

## While working

3. Append a log entry to `AGENT_LOG.md` for each meaningful action. Format:

   ```
   ## <YYYY-MM-DD HH:MM> — <agent name>
   - Action: <what was done>
   - Files: <files changed / objects created>
   - Result: <outcome, commands run>
   - Next: <suggested next step>
   ```

4. Keep `TODO.md` current: mark tasks `done`, add new tasks with the next id, adjust priority. `TODO.md` is the human translation of the log — after logging technical actions, update `TODO.md` so the user always has readable next steps.

## At the end of a session

5. Regenerate the Overleaf annex from `TODO.md`:

   ```r
   source("R/99_generate_todo_annex.R")
   ```

   This rewrites `paper/sections/99_todo_annex.tex`. Do not hand-edit that file; edit `TODO.md` and regenerate.

## Plan adherence (important)

The user sometimes loses track and asks to jump to a different step. Guard the plan:

- The active plan lives in `IMPLEMENTATION_PLAN.md`, `TODO.md`, and any preregistration in `prestudy/` or `OSF/`.
- If the user requests something that deviates from the current planned next step, do NOT silently comply. First ask explicitly, e.g.:
  "The plan's next step is **<planned step>**, but you're asking to do **<requested step>**. Do you really want to switch, or should I continue with the plan?"
- Proceed with the deviation only on an explicit "yes". Otherwise continue as planned.
- This does not apply to small clarifications or fixes — only to real changes in direction or skipping planned steps.

## TODO.md format

A markdown table the R generator can parse. Columns exactly: `Section | ID | Task | Priority | Status`.

- Priority: `high`, `medium`, or `low`.
- Status: `done`, `in-progress`, or `pending`.
- IDs are integers, unique, assigned in order.
