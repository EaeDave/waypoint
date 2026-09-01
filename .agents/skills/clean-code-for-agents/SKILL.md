---
name: clean-code-for-agents
description: Apply a Clean Code discipline re-ranked for AI coding agents (the primary reader of code is now the agent, not a human) together with a targeted verification loop (tests as specification, not TDD ceremony), and persist ONLY non-inferable project facts into AGENTS.md (the cross-tool standard, with a CLAUDE.md bridge) so they survive across sessions and tools. Use this WHENEVER writing, implementing, refactoring, or reviewing code in a real project; when setting up or bootstrapping a new repo; when the user asks to "work in this pattern", mentions Clean Code, XP, TDD, agent-friendly code, greppable names, small functions, or wants coding standards / agent rules installed. Trigger even if the user does not say "Clean Code" — any request to make a codebase agent-friendly, enforce a coding standard, or set up a CLAUDE.md/AGENTS.md rules file qualifies. Do NOT use for one-off throwaway snippets where no project context exists.
---

# Clean Code for AI Agents

## Premise

In 2008 *Clean Code* optimized code for the next human reader. The primary
reader is now the **AI agent** that greps, reads in truncated ranges, edits,
and tests the code. Same principles, re-ranked; one inverts (comments), one is
demoted with a nuance (DRY), and the persistence layer is now evidence-gated:
every line an agent re-reads each session must earn its tokens.

## Evidence base

This version is calibrated against measured results, not taste:

- **Context files**: providing them does not generally raise task success and
  adds **+20% inference cost** — but instructions in them ARE followed, and
  they pay off precisely for **non-standard practices** (Gloaguen et al.,
  arXiv:2602.11988, 138 instances / 4 agents). Human-curated, non-redundant
  AGENTS.md cut runtime **−28.6%** and output tokens **−16.6%** (Lulla et al.,
  arXiv:2601.20404). Conclusion: curation wins, redundancy costs.
- **TDD**: prescribing a procedural test-first workflow made agents WORSE —
  regressions rose 6.08% → **9.94%**; giving them targeted context about which
  tests to verify cut regressions **−70%** (TDAD, arXiv:2603.17973). Human
  tests as specification: 94.3% success vs 68% with self-generated tests
  (TDFlow, EACL 2026). Context beats ceremony.
- **Rules-file size**: practitioner consensus (Anthropic context-engineering,
  HumanLayer, Osmani) converges on ≤~100 lines with progressive disclosure;
  instruction-following degrades past ~150–200 instructions
  (arXiv:2507.11538). These caps are expert consensus, not benchmarks — the
  cost of redundancy above IS measured.
- **Unit size**: the binding limit is the *total context a task assembles*,
  not one file's length. Successful agent trajectories cluster at 20–30k
  tokens; by 64k the resolve rate falls to 0–7% **even with perfect
  retrieval** (arXiv:2602.16069). Length alone costs 13.9–85% accuracy
  *within* the claimed window, even with retrieval perfect and the
  irrelevant tokens masked out (Du et al., EMNLP 2025 findings.1264).
  Lexical recall survives (>95%); *semantic* recall is what collapses
  (−53% median, Štorek et al., ACL 2026 long.19). Meanwhile per-line defect
  density is **higher** in small modules, not lower (Koru et al., IEEE TSE
  2009, DOI 10.1109/TSE.2008.90, power law; Basili & Perricone 1984,
  16.0→6.4 errors/KLOC as size rises), and the 200-line "optimum" U-curve
  is a mathematical artifact of how the data was binned (Jones, 2023).
  Only one size figure has modern backing: Java methods ≲24 SLOC
  (Chowdhury et al., MSR 2022, 785k methods, 49 projects).

## The two jobs

1. **Behave** — write/edit code right now per the principles and the
   verification loop below.
2. **Persist** — keep a lean, marker-delimited rules block in `AGENTS.md`
   (cross-tool standard) with a minimal `CLAUDE.md` bridge, admitting ONLY
   non-inferable facts. Idempotent.

Do both on any real project; if the user wants just one, do that one.

## The admission filter (what may be persisted)

> Can the agent discover this by reading the code? Then delete it.

Only three things belong in the rules block: **commands** (test/lint/
typecheck/build), **non-standard practices** (facts an agent gets wrong by
assuming defaults), and **known failure points**. Generic style rules,
repository overviews, and restated conventions are the measured +20%-cost
noise. Style is the formatter's job. Keep the block ≤40 lines and the whole
rules file ≤~100 lines — if the project's file is already bigger, flag it and
move detail into `docs/*` referenced on demand (progressive disclosure).

## Re-ranked principles (apply while coding)

Ordered most-impactful first.

1. **Right-sized units — measured by context, never by a line quota.**
   Files have **no line budget**. Split a file when it has two reasons to
   change, not when it crosses a number; splitting on arbitrary boundaries
   measurably hurts (chunking at raw function boundaries costs 3.57–5.64pp
   EM, Cliff's δ = −1.0, and is never Pareto-optimal; unit *size* itself has
   only a weak, non-monotonic effect — arXiv:2605.04763) and every extra
   fragment is another hop the agent must navigate. Functions: one whole
   idea, ~≤25 SLOC as a soft signal — a longer straight-line function beats
   an indirection the agent has to chase. **Never refactor solely to hit a
   line count.** The real test: *can the agent finish a task by grepping a
   symbol and reading one region, without loading the whole file?* Yes → the
   file is fine at any length. No → the defect is cohesion or naming, not
   size. Budget the working set (~20–30k tokens), not the file.
2. **Single Responsibility.** One reason to change; lets the agent isolate,
   test, and edit without side effects.
3. **Meaningful, unique, greppable names.** Grep is the navigation API. If a
   name returns 50 irrelevant hits, it is a bad name. Avoid `data`, `handler`,
   `Manager`, `Service`.
4. **Comments carry context and provenance** *(inverts)*. The agent has
   perfect syntax fluency but no idea WHY — the prod bug, the upstream issue,
   the business constraint. Docstrings with intent + a usage example. **Never
   strip comments on refactor — including the agent's own.**
5. **Explicit types.** Free ground truth instead of inferring types from
   usage. Often the highest-leverage migration in an untyped codebase.
6. **Locality of behavior over reflexive DRY** *(revised)*. Deduplicate
   business logic that must change together; tolerate small local duplication
   when extracting it would add an indirection layer the agent must navigate.
   Share at domain boundaries, not through grab-bag utils. (OpenAI harness
   engineering; arXiv:2604.07502.)
7. **Tests runnable headless, one command, parseable output.** Prefer JSON
   reporters. See the verification loop.
8. **Predictable structure.** Framework conventions let the agent anticipate
   paths without listing directories.
9. **Dependency injection at boundaries.** Swap a real collaborator for a
   named fake without monkey-patching; centralize config behind named
   constants/env vars.
10. **Shallow nesting.** Guard clauses, early returns; aim ≤2 levels.
11. **Errors with context.** Include the offending value and expected shape —
    the message is the agent's debug signal.
12. **Limits are constraints, not suggestions.** Wire the formatter, the
    linter, and nesting caps into CI. The formatter decides style; nobody
    debates it. A repo MAY add a file-size cap — but as a *review trigger*
    for a cohesion check, never as an automatic mandate to split.

## The verification loop (replaces the XP ritual)

Prescribing red-green ceremony measurably hurts; targeted verification
measurably helps. Work like this:

1. Before editing, find the tests that cover what you touch (grep the
   symbol's usages and test files). Run them for a baseline.
2. Make the change small — one behavior per commit.
3. Re-run the targeted tests, then the relevant suite. Never done on red.
4. **Existing human-written tests are the specification.** Never weaken,
   skip, or delete one to make a patch pass.
5. A test the agent generated only becomes a safety net after confirming it
   fails on the unfixed code (otherwise it verifies nothing).
6. Bug fix → regression test. Commit message records the *why*.

## Project scaffolding (set up once)

- `AGENTS.md` as a lean index; details live in `docs/*`, loaded on demand.
- Machine-readable tool output: linter/test JSON flags where available.
- Nesting caps enforced by CI/linter; any size cap wired as a warning that
  prompts a cohesion review, not a hard failure.
- Docs in-repo and versioned — agents cannot see wikis or Google Docs.
- Idempotent setup script (`bin/setup`) taking a clean machine to working.
- Structured JSON logs for services; plain text only for user-facing CLI.

## Workflow when this skill triggers

### Step 1 — Read the project before changing anything
Detect language, framework, conventions, and the real values for the
template: test / lint / typecheck / build commands, the formatter in use,
non-standard practices, failure points. **Never invent a command.** No
headless test command? That is the first thing to fix — flag it.

### Step 2 — Apply the discipline to the work at hand
Follow the principles and the verification loop. Prefer small test-backed
steps over a big rewrite.

### Step 3 — Install / update the rules block (persistence)
1. Pick the canonical file: `AGENTS.md` exists → write there; only
   `CLAUDE.md` exists → respect it and offer (don't force) migration;
   neither → create `AGENTS.md`.
2. Read `assets/agent-rules.md` (sibling to this file) — the canonical block,
   delimited by `<!-- clean-code-agents:start/end -->` markers.
3. Fill placeholders with real values from Step 1; delete sections that
   genuinely don't apply. Never leave an unfilled placeholder.
4. Insert idempotently: replace between markers if present, else append.
5. **Bridge for Claude Code**: a minimal `CLAUDE.md` containing `@AGENTS.md`
   (preferred over a symlink — Windows-safe). If `CLAUDE.md` has unrelated
   content, append the import line instead of overwriting.
6. Run the admission filter over the result: anything inferable from the
   code gets cut. Whole file ≤~100 lines or flag it.

### Step 4 — Summarize
What changed and that its tests pass; where the block landed and whether a
bridge was added; any TODO placeholder (especially a missing test command);
anything the admission filter removed and why.

## Principles

- **The agent is the reader.** Optimize for grep, truncated reads, and
  full-attention units.
- **Every persisted line must earn its tokens.** Redundant context is a
  measured cost, not a style preference.
- **Context beats ceremony.** Tell the agent which tests to run, not which
  ritual to perform.
- **Idempotent.** Re-running the skill improves code and rules without
  duplicating anything.
- **Adapt, don't dogmatize.** No number here is a target. Cohesion,
  greppability, and the size of the working set decide; line counts are at
  most a prompt to go look. Tune per language/team and say what you changed.
