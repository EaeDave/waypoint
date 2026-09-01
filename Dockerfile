# syntax=docker/dockerfile:1

FROM rust:1.89-bookworm AS dependencies
WORKDIR /source
ENV CARGO_INCREMENTAL=0

COPY Cargo.toml Cargo.lock ./
COPY server/Cargo.toml ./server/Cargo.toml
RUN mkdir --parents server/src \
    && printf 'fn main() {}\n' > server/src/main.rs
RUN --mount=type=cache,id=waypoint-cargo-registry,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,id=waypoint-cargo-target,target=/source/target,sharing=locked \
    cargo build --locked --release --package waypoint-api

FROM dependencies AS builder
RUN rm --recursive --force server/src
COPY server/src ./server/src
COPY server/migrations ./server/migrations
RUN --mount=type=cache,id=waypoint-cargo-registry,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,id=waypoint-cargo-target,target=/source/target,sharing=locked \
    cargo build --locked --release --package waypoint-api \
    && cp /source/target/release/waypoint-api /waypoint-api

FROM debian:bookworm-slim AS runtime
LABEL org.opencontainers.image.source="https://github.com/EaeDave/waypoint" \
      org.opencontainers.image.description="Waypoint self-hosted synchronization API"
RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --home-dir /nonexistent --shell /usr/sbin/nologin waypoint

COPY --from=builder /waypoint-api /usr/local/bin/waypoint-api

ENV WAYPOINT_BIND=0.0.0.0:8787 \
    RUST_LOG=info
EXPOSE 8787
USER waypoint

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl --fail --silent --show-error http://127.0.0.1:8787/health >/dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/waypoint-api"]
