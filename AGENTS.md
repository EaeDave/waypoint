# Waypoint agent guide

## Product and architecture

Waypoint is a local-first calendar, task, and habit tracker for Linux and Android. Preserve these boundaries:

- `src/core/` owns domain rules and SQLite persistence.
- `src/sync/` and `server/` own synchronization; the server is a Rust/Axum API backed by PostgreSQL.
- `qml/` owns presentation only. Linux uses `src/app/`; Android uses `src/mobile/` plus `android/`.
- `src/daemon/`, `src/cli/`, and `src/reminders/` provide the Linux background service, CLI, and notifications.
- `plugins/omarchy-waypoint/` is an optional `omarchy-shell` bar plugin that talks to the local daemon.
- `packaging/`, `install.sh`, and `bin/` own distribution and developer setup.

Read `README.md` for supported platforms, user installation, server setup, and release configuration before changing deployment behavior.

## Default delivery path

Optimize for users who do not want to build the project:

1. Linux users install the latest release with the command in `README.md`; do not substitute a source build.
2. Android users install `waypoint-android-arm64.apk` from the latest GitHub release.
3. Self-hosters deploy `compose.yaml` behind an HTTPS reverse proxy. Prefer this over running the API directly.
4. Configure every client with `https://<host>/v1/sync` and the same `WAYPOINT_SYNC_TOKEN`.

The service is single-user. A token grants full access to an instance; deploy separate instances for separate trust boundaries.

## Deploy the synchronization server

For a repository checkout on a Linux host with Docker Compose:

1. Copy `.env.example` to `.env`.
2. Generate `POSTGRES_PASSWORD` with `openssl rand -hex 24` and use the same value in the host-only `DATABASE_URL`.
3. Generate `WAYPOINT_SYNC_TOKEN` with `openssl rand -hex 32`.
4. Run `docker compose up --build --detach`.
5. Require `curl --fail http://127.0.0.1:${WAYPOINT_PORT:-8787}/health` to return `{"status":"ready"}`.
6. Put Caddy, nginx, Traefik, or the hosting platform's TLS proxy in front of the loopback listener. Never expose an HTTP endpoint to Android.
7. Configure a client and complete a real sync before declaring the deployment finished.

For a container platform, build the root `Dockerfile`, expose container port `8787`, attach PostgreSQL, and provide:

- `DATABASE_URL`
- `WAYPOINT_SYNC_TOKEN` (32–512 characters)
- `WAYPOINT_BIND=0.0.0.0:8787`
- optionally `RUST_LOG`
- optionally `WAYPOINT_FIREBASE_SERVICE_ACCOUNT_JSON` for Android push wakeups

The Firebase service-account JSON is a server secret. The four `WAYPOINT_FIREBASE_*` Android application values are build-time identifiers, not a replacement for that credential. Without Firebase, periodic synchronization remains available.

Never commit or print `.env`, Bearer tokens, service-account JSON, Android keystores, signing passwords, databases, or generated APKs. Preserve the named PostgreSQL volume during updates; `docker compose down --volumes` is destructive.

## Release contract

CI runs on pushes and pull requests. A successful `main` CI run triggers `.github/workflows/release.yml`; it publishes only when the version has no matching tag.

Before a release:

1. Set the same semantic version in `CMakeLists.txt`, `server/Cargo.toml`, `Cargo.lock` (`waypoint-api`), and `plugins/omarchy-waypoint/manifest.json`.
2. Ensure repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`, and `ANDROID_KEY_PASSWORD` exist.
3. Ensure repository variables `WAYPOINT_FIREBASE_APPLICATION_ID`, `WAYPOINT_FIREBASE_API_KEY`, `WAYPOINT_FIREBASE_PROJECT_ID`, and `WAYPOINT_FIREBASE_SENDER_ID` describe the maintainer's Firebase Android app.
4. Push `main`, then require CI and the release workflow to succeed.
5. Verify the GitHub release contains the signed Android APK, Linux archive, checksums, and license.

Never replace or lose the Android signing key: upgrades must use the same key.

Cut a release automatically, without asking: when a PR changes anything that reaches end users (app, CLI, daemon, plugin, server, packaging), bump the patch version in that same PR before merging. Skip the bump only for docs, CI, or tests. Before merging, rebase on `main` and confirm the version has no existing tag; a duplicate version is silently not released.

Commit every skill change (`.agents/skills/`, `.claude/skills/`, `skills-lock.json`) to the repository in the PR of the card that prompted it.

## Work tracking (Plane)

Project `Waypoint`, identifier `WAY`, id `61eaddab-f10a-45ae-a94b-039c818f7266`, workspace `eaedave`. Use the `mcp__plane_*` tools.

- Every task is a card `WAY-<n>`. Find or create it before starting.
- Every card ships as one PR. Put `WAY-<n>` in the branch, commit subjects, and PR title.
- Before opening a UI PR, exercise the change locally and include the result and a screenshot in the PR description. If a lower-resolution secondary monitor is available, use it without interrupting work on the primary monitor.
- Set In Progress while you edit the card and while its PR is open. Set Done only when the PR is merged.
- State ids for `workitem update --state`: Backlog `d9bb63fc-1795-42da-83fd-e1183fa25422` (untouched); Todo `b87b1d86-0c58-4c56-bd3b-8d84d8f55f75` (planned); In Progress `12ed076a-c595-4db5-ae60-a194c18912d0`; Done `dd664432-c1e4-4371-8999-5b8c2aab6c0a` (PR merged); Cancelled `f4a7520c-de54-4a02-b4d6-bee5d8d6f0f7` (dropped, no PR).

<!-- clean-code-agents:start -->
## Agent rules — non-inferable project facts only

### Commands
- Test: `cmake --build --preset dev && ctest --preset dev && cargo test --workspace`
- Lint: `cmake --build build/dev --target waypoint_qmllint && cargo clippy --workspace --all-targets -- -D warnings`
- Typecheck: `cmake --build --preset dev && cargo check --workspace`
- Build: `cmake --build --preset dev && cargo build --workspace`
- Container: `docker build --tag waypoint-api .`
- Android APK: `bin/build-android` (outputs `waypoint-android-arm64-debug.apk`)

### Architecture
- QML owns presentation only; persistence, sync, and date rules stay in typed C++ models.

### Non-standard practices
- Date-only tasks are floating calendar dates. Never convert `scheduled_date` through UTC.
- Task times are floating local wall-clock `HH:mm` values. Never convert them through UTC.

### Known failure points
- `waypoint-ipc-v1` is single-instance. Never unlink its socket before probing a live daemon.
- The Omarchy plugin runs inside `omarchy-shell`; never expose the persisted sync token through IPC/QML.
- `rescanPlugins` does not replace an active bar-widget QML object reliably; use `omarchy restart shell` after plugin source changes.
<!-- clean-code-agents:end -->
