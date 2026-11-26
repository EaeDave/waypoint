---
name: clean-code-for-agents
description: Clean Code tuned for AI coding agents. Vertical slices with tool-checked boundaries, testable modules, targeted test verification, and a lean AGENTS.md that holds only non-inferable facts. Use when writing, refactoring, or reviewing code in a real project, bootstrapping a repo, or installing agent rules or coding standards. Skip throwaway snippets.
---

# Clean Code for AI Agents

The main reader of code is now an agent that greps, reads ranges, edits, and
runs tests. Clean code lowers its cost and navigation; it does not raise
correctness. Prose rules erode, so anything a tool can enforce becomes a
check. Sources: [references/evidence.md](references/evidence.md).

## Structure

1. **Vertical slices by default.** Group code by feature, not by layer. One
   folder per feature holds its entry point, logic, data access, and tests.
   Use the project's existing naming (`src/orders/`, `features/orders/`,
   `modules/orders/`); the folder name is not the rule.
   - Each slice exposes one public entry (`index`, `mod`, package API).
     Other slices import only that.
   - Shared code lives in a small kernel that never imports from a slice.
   - Enforce the boundary in CI (import-linter, ArchUnit,
     eslint-plugin-boundaries, dependency-cruiser, Nx, Go `internal/`, Rust
     visibility). A boundary written only in AGENTS.md will be crossed.
2. **Opinionated frameworks win.** Rails, Laravel, Django, Phoenix, Angular
   and similar: follow their layout. Group by feature only through the
   framework's own unit (Django apps, Rails engines, Phoenix contexts).
3. **Legacy layered repos migrate gradually.** New features go in a slice.
   Move an old feature only while working in it, in a refactor-only commit.
4. **Testable modules.** Test each slice through its public entry. Inject
   I/O (DB, HTTP, clock, queue) at the slice edge so tests use named fakes.

## Code

- **Size by working set, not line count.** Split a file when it has two
  reasons to change. Never split only to hit a number. Test: can the agent
  finish a task by grepping a symbol and reading one region? Functions hold
  one idea; ~25 SLOC is a soft signal.
- **Greppable names.** If a name returns 50 irrelevant hits, rename it.
  Avoid `data`, `handler`, `Manager`, `Service`.
- **Comments carry the why:** the prod bug, the upstream issue, the business
  rule. Never strip existing comments on refactor.
- **Explicit types**, especially at slice entries. They are the contract.
- **Reuse before adding.** Search for an existing helper or dependency
  first. Tolerate small duplication only when sharing would couple slices.
- **Never loosen validation or error handling as a side effect.** If you
  must, say so in the commit and add a test.
- **Errors name the bad value and the expected shape.**
- **Shallow nesting:** guard clauses, at most ~2 levels.

## Verification loop

1. Find the tests covering what you touch; run them for a baseline.
2. One behavior per commit. Refactors go in their own commit.
3. Re-run targeted tests, the relevant suite, and the boundary check. Never
   done on red.
4. Existing human tests are the spec. Never weaken, skip, or delete one.
5. New tests: state pre/post-conditions and invalid inputs first. A test
   counts only after it fails on the unfixed code.
6. Bug fix gets a regression test; the commit records why.

Do not prescribe red-green ceremony; targeted verification is what helps.

## Checks in CI

Formatter, linter, typecheck, boundary check, nesting cap, and a
complexity/duplication ratchet (fail when a touched file gets worse). A file
size cap, if any, only warns and triggers a cohesion review. Tests run
headless with one command and machine-readable output.

## Persisting rules (AGENTS.md)

Admission filter, in order:
1. A tool can enforce it? Make it a check, not a line.
2. The agent can read it from the code? Drop it.
3. Keep only commands, the architecture rule in one line, non-standard
   practices, and known failure points.

State boundaries as rules, never as lists of forbidden paths. Block at most
40 lines; whole file at most ~100, with detail in `docs/*`.

## Workflow

1. **Read the project.** Find test/lint/typecheck/build commands, formatter,
   architecture (slices, framework layout, or layers), boundary tooling,
   non-standard practices, and failure points. Never invent a command; a
   missing headless test command is the first thing to flag.
2. **Do the work** with the rules above. New feature goes in a new slice or
   the framework's place for it.
3. **Install the rules block.**
   - Target `AGENTS.md`. If only `CLAUDE.md` exists, respect it and offer
     migration. If neither exists, create `AGENTS.md`.
   - Fill [assets/agent-rules.md](assets/agent-rules.md) with real values;
     delete sections that do not apply; leave no placeholder.
   - Replace between `<!-- clean-code-agents:start/end -->` markers, else
     append. Re-running must not duplicate.
   - Add a `CLAUDE.md` bridge containing `@AGENTS.md`, or append that line
     if `CLAUDE.md` has other content.
   - Run the admission filter. Propose checks for enforceable rules.
4. **Report** what changed and that tests pass, where the block landed,
   which rules became checks, open placeholders, and what the filter cut.
