<!-- clean-code-agents:start -->
## Agent rules: non-inferable project facts only

If a tool can enforce a rule, it lives in a check, not here. If an agent can
read a fact from the code, it does not belong here. Keep this block under 40
lines.

### Commands (run these, never guess)
- Test: `<TEST_COMMAND>`
- Lint: `<LINT_COMMAND>`
- Typecheck: `<TYPECHECK_COMMAND>`
- Build: `<BUILD_COMMAND>`
- Boundaries: `<BOUNDARY_CHECK_COMMAND>`
Prefer machine-readable output where supported (JSON reporter flags).

### Architecture
- <ARCHITECTURE_RULE>
<!-- One line, the rule only; never list forbidden module paths. E.g.
     "New features go in their own folder under src/<feature>/; features use
     each other only through their public entry." or, for an opinionated
     framework, "Follow Rails conventions; group by feature only via engines." -->

### Verify before you declare done (targeted verification)
- Find the tests covering what you touch and run them first for a baseline.
- After the change re-run them, then the relevant suite and the boundary
  check. Never done on red.
- Existing tests are the specification: never weaken, skip, or delete one.
- New tests: state the contract (pre/post-conditions, invalid inputs) first;
  a test counts only after it fails on the unfixed code. Bug fix gets a
  regression test.
- Never loosen input validation or error handling as a side effect.
- Refactors go in their own commit, never mixed into a fix or feature.

### Non-standard practices in this repo
<!-- Facts an agent gets wrong by assuming defaults, e.g. "uses uv, never pip".
     Delete this section if there are none. -->
- <NON_STANDARD_PRACTICES>

### Known failure points (defensive code required here, nowhere else)
- <FAILURE_POINTS>
<!-- clean-code-agents:end -->
