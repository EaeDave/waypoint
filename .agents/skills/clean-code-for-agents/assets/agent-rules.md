<!-- clean-code-agents:start -->
## Agent rules — non-inferable project facts only

Admission filter: if an agent can discover a fact by reading the code, it does
NOT belong in this file. Redundant context costs ~20% extra inference for zero
gain (arXiv:2602.11988). Keep this block under 40 lines.

### Commands (run these, never guess)
- Test: `<TEST_COMMAND>`
- Lint: `<LINT_COMMAND>`
- Typecheck: `<TYPECHECK_COMMAND>`
- Build: `<BUILD_COMMAND>`
Prefer machine-readable output where supported (JSON reporter flags).

### Verify before you declare done (targeted verification)
- Before changing code, find which tests cover what you touch (grep the
  symbol's usages and its test files) and run those first for a baseline.
- After the change, re-run them, then the relevant suite. Never done on red.
- Existing tests are the specification: never weaken, skip, or delete one to
  make a patch pass. Every bug fix gets a regression test.
- A test you generated yourself only counts as a safety net after you confirm
  it fails on the unfixed code.

### Non-standard practices in this repo
<!-- Only genuinely non-obvious, project-specific facts an agent would get
     wrong by assuming defaults. Examples: "uses uv, never pip";
     "DB migrations via bin/migrate, not the ORM"; "lib X is vendored and
     patched — never update it". Delete this section if there are none. -->
- <NON_STANDARD_PRACTICES>

### Known failure points (defensive code required here, nowhere else)
- <FAILURE_POINTS>

### Style
- The formatter and linter decide style; run them, don't debate them.
  No style rules live in this file by design.
<!-- clean-code-agents:end -->
