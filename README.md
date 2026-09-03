# Waypoint

[![CI](https://github.com/EaeDave/waypoint/actions/workflows/ci.yml/badge.svg)](https://github.com/EaeDave/waypoint/actions/workflows/ci.yml)

Waypoint is a local-first task, calendar, and habit tracker for Linux and Android. Data is stored locally in SQLite and can be synchronized through the self-hosted Waypoint API. The Linux application also provides a daemon, command-line client, reminders, and an optional Omarchy bar plugin.

## Features

- Date-based and recurring tasks
- Daily habits with fixed, manual, and complete-all check-ins
- Local SQLite storage with an offline outbox
- Linux desktop application, daemon, CLI, and notifications
- Android application, reminders, background synchronization, and home-screen widget
- Self-hosted synchronization API backed by PostgreSQL
- Optional Firebase Cloud Messaging wakeups with polling fallback
- Brazilian national, state, municipal, commemorative, and optional holidays

## Installation

### Linux x86_64

Install the latest release for the current user:

```bash
curl -fsSL https://raw.githubusercontent.com/EaeDave/waypoint/main/install.sh | bash
```

The installer verifies the release checksum, installs the application under `~/.local/lib`, creates commands in `~/.local/bin`, installs the desktop entry, and enables the `waypointd` user service. If Omarchy is installed, it also enables the Waypoint bar plugin.

Ensure `~/.local/bin` is in `PATH`, then launch:

```bash
waypoint
```

The release package currently targets glibc-based Linux distributions on x86_64.

### Android

Download `waypoint-android-arm64.apk` from the [latest GitHub release](https://github.com/EaeDave/waypoint/releases/latest). Android may ask for permission to install applications from the browser or file manager used to open the APK.

Requirements:

- Android 9 or newer (API 28+)
- arm64-v8a device
- HTTPS synchronization endpoint; cleartext HTTP is disabled in the Android application

The GitHub release is currently the only Android distribution channel.

## Synchronization server

Waypoint is a single-user service. One shared Bearer token grants full access to tasks, habits, holiday preferences, and registered push devices. Run a separate instance and token for each trust boundary.

### Docker Compose

Requirements:

- Docker Engine 24 or newer
- Docker Compose v2
- A hostname and TLS reverse proxy for remote clients

Create the environment file and replace both placeholder secrets:

```bash
cp .env.example .env
openssl rand -hex 24
openssl rand -hex 32
```

Use the first value as `POSTGRES_PASSWORD` and in the password portion of `DATABASE_URL`. Use the second value as `WAYPOINT_SYNC_TOKEN`. Then start PostgreSQL and the API:

```bash
docker compose up --build --detach
curl --fail http://127.0.0.1:8787/health
```

The expected response is:

```json
{"status":"ready"}
```

The Compose stack exposes the API only on `127.0.0.1`. Put a TLS reverse proxy such as Caddy, nginx, or Traefik in front of it before connecting a remote client. A minimal Caddy route is:

```caddyfile
waypoint.example.com {
    reverse_proxy 127.0.0.1:8787
}
```

Operational commands:

```bash
docker compose logs --follow api
docker compose pull
docker compose up --build --detach
docker compose down
```

`docker compose down` preserves the named PostgreSQL volume. Add `--volumes` only when intentionally deleting all synchronized server data.

### Run the API directly

Requirements:

- Rust 1.89 or newer
- PostgreSQL 14 or newer
- A database and user represented by `DATABASE_URL`

Load the environment and start the server:

```bash
cp .env.example .env
# Edit DATABASE_URL and WAYPOINT_SYNC_TOKEN first.
set -a
source .env
set +a
cargo run --locked --release --package waypoint-api
```

Database migrations run automatically during startup. The default listener is `127.0.0.1:8787`.

### Firebase push wakeups

Firebase Cloud Messaging is optional. Without it, Android continues to synchronize through the polling fallback.

For the server, set `WAYPOINT_FIREBASE_SERVICE_ACCOUNT_JSON` to the compact contents of a Firebase service-account JSON file. This value contains a private key and must be stored only in the deployment platform's secret store. Never commit the JSON file or value.

For Android builds, provide all four non-secret Firebase application values:

- `WAYPOINT_FIREBASE_APPLICATION_ID`
- `WAYPOINT_FIREBASE_API_KEY`
- `WAYPOINT_FIREBASE_PROJECT_ID`
- `WAYPOINT_FIREBASE_SENDER_ID`

## Configure a client

Open **Settings** in the Linux or Android application and enter:

- Server endpoint: `https://waypoint.example.com/v1/sync`
- Bearer token: the value of `WAYPOINT_SYNC_TOKEN`

Use HTTPS whenever the endpoint leaves the local machine. The token authorizes the complete instance and should not be shared, logged, committed, or embedded in support output.

## Build from source

### Linux desktop

Requirements:

- CMake 3.28 or newer
- Ninja
- C++20 compiler
- Qt 6.8 or newer with Core, DBus, GUI, Network, QML, Quick, Quick Controls 2, SQL, and Test
- Qt SQLite driver
- Rust 1.89 or newer

Configure, build, test, and install for the current user:

```bash
cmake --preset dev
cmake --build --preset dev
ctest --preset dev
cargo test --workspace
cmake --install build/dev --prefix "$HOME/.local"
```

For an optimized build:

```bash
cmake --preset release
cmake --build --preset release
```

`bin/setup` performs a developer installation and wires the Omarchy plugin from the checkout.

### Android APK

Requirements:

- Qt 6.9.3 host and Android kits
- Android SDK platform 35 and build tools 35.0.0
- Android NDK 27.2.12479018
- Java 17
- CMake and Ninja

Set tool locations when they differ from the defaults in `bin/build-android`, then build:

```bash
export QT_HOST_ROOT="$HOME/Qt/6.9.3/gcc_64"
export QT_ANDROID_ROOT="$HOME/Qt/6.9.3/android_arm64_v8a"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/27.2.12479018"
export JAVA_HOME="/path/to/jdk-17"
ANDROID_ABI=arm64-v8a ANDROID_BUILD_TYPE=Debug bin/build-android
```

The output is `waypoint-android-arm64-debug.apk`. Set the optional Firebase application variables from `.env.example` to enable push wakeups.

Release builds require a stable signing key:

```bash
export QT_ANDROID_SIGN_APK=ON
export QT_ANDROID_KEYSTORE_PATH=/absolute/path/to/waypoint-release.jks
export QT_ANDROID_KEYSTORE_ALIAS=waypoint
export QT_ANDROID_KEYSTORE_STORE_PASS='...'
export QT_ANDROID_KEYSTORE_KEY_PASS='...'
ANDROID_BUILD_TYPE=Release bin/build-android
```

Never publish or lose the signing keystore. Android updates must be signed by the same key.

## Development checks

Run the complete local verification suite:

```bash
cmake --build --preset dev
ctest --preset dev
cargo test --workspace
cmake --build build/dev --target waypoint_qmllint
cargo clippy --workspace --all-targets -- -D warnings
cargo audit --ignore RUSTSEC-2023-0071
```

`RUSTSEC-2023-0071` applies to the optional `rsa` crate retained in `Cargo.lock` by `sqlx-postgres`. It is not present in Waypoint's selected dependency graph (`cargo tree -i rsa` is empty). FCM signing uses the `aws-lc-rs` backend.

Android UI smoke tests are defined under `.maestro/`.

## Continuous integration and releases

`.github/workflows/ci.yml` builds and tests Linux, audits Rust dependencies, and builds a generic arm64 debug APK without Firebase configuration for every pull request and push to `main`.

`.github/workflows/release.yml` reads the semantic version from `CMakeLists.txt`. When `main` contains a version without a corresponding `v<version>` tag, it builds the maintainer's signed, Firebase-enabled Android APK and a bundled Linux package, creates the tag, generates checksums, and publishes a GitHub release. `server/Cargo.toml` must contain the same version.

Configure these GitHub Actions repository secrets before the first release:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_ALIAS`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

Add the four `WAYPOINT_FIREBASE_*` Android values listed above as GitHub Actions repository variables. They are embedded in the maintainer's released APK and therefore are identifiers, not confidential credentials. Forks should replace them with their own Firebase Android application values. Keep `WAYPOINT_FIREBASE_SERVICE_ACCOUNT_JSON` server-only.

Create and encode a signing key with:

```bash
keytool -genkeypair -v \
  -keystore waypoint-release.jks \
  -alias waypoint \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
base64 -w 0 waypoint-release.jks
```

To publish a new release, update both version declarations and push to `main`:

```cmake
project(Waypoint VERSION 0.2.0 LANGUAGES CXX)
```

```toml
[package]
version = "0.2.0"
```

## Repository layout

- `src/` — C++ core, synchronization, desktop, daemon, CLI, and mobile bridge code
- `qml/` — Linux and Android interfaces
- `android/` — Android manifest, services, widget, and Gradle additions
- `server/` — Rust synchronization API and PostgreSQL migrations
- `plugins/omarchy-waypoint/` — Omarchy bar plugin
- `packaging/` — desktop entry, icon, and systemd user service
- `tests/` — C++ behavioral tests
- `.maestro/` — Android UI smoke tests

## Security notes

- `.env`, Android keystores, Firebase service-account files, databases, and generated APKs must remain untracked.
- The API container runs as an unprivileged user and binds to localhost through the Compose stack.
- The API requires a 32–512 character Bearer token and compares it in constant time.
- Android rejects cleartext HTTP synchronization endpoints.
- GitHub Actions use read-only permissions by default; only the release publishing job receives `contents: write`.
- Third-party Linux deployment binaries are pinned to immutable releases and verified by SHA-256.

## License

Waypoint is free software licensed under the [GNU Affero General Public License, version 3 or later](LICENSE). You may use, study, modify, and redistribute it under the terms of that license. Modified versions offered over a network must provide their corresponding source code to their users.

Copyright © 2026 EaeDave.
