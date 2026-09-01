<!-- clean-code-agents:start -->
## Agent rules — non-inferable project facts only

### Commands
- Test: `cmake --build --preset dev && ctest --preset dev && cargo test --workspace`
- Lint: `cmake --build build/dev --target waypoint_qmllint && cargo clippy --workspace --all-targets -- -D warnings`
- Typecheck: `cmake --build --preset dev && cargo check --workspace`
- Build: `cmake --build --preset dev && cargo build --workspace`
- Container: `docker build --tag waypoint-api .`

### Non-standard practices
- Date-only tasks are floating calendar dates. Never convert `scheduled_date` through UTC.
- Task times are floating local wall-clock `HH:mm` values. Never convert them through UTC.
- QML owns presentation only; persistence, sync, and date rules stay in typed C++ models.

### Known failure points
- `waypoint-ipc-v1` is single-instance. Never unlink its socket before probing a live daemon.
- The Omarchy plugin runs inside `omarchy-shell`; never expose the persisted sync token through IPC/QML.
- `rescanPlugins` does not replace an active bar-widget QML object reliably; use `omarchy restart shell` after plugin source changes.

### Style
- Formatters and linters decide style; no manual style rules live here.
<!-- clean-code-agents:end -->
