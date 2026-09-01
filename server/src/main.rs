use sqlx::postgres::PgPoolOptions;
use std::{env, net::SocketAddr};
use tracing_subscriber::EnvFilter;
use waypoint_api::{AppState, router};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .json()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .init();

    let database_url = required_environment("DATABASE_URL")?;
    let sync_token = required_environment("WAYPOINT_SYNC_TOKEN")?;
    let bind_address: SocketAddr = env::var("WAYPOINT_BIND")
        .unwrap_or_else(|_| "127.0.0.1:8787".to_owned())
        .parse()?;

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&database_url)
        .await?;
    sqlx::migrate!().run(&pool).await?;

    let listener = tokio::net::TcpListener::bind(bind_address).await?;
    tracing::info!(address = %bind_address, "Waypoint API is ready");
    axum::serve(listener, router(AppState::new(pool, sync_token))).await?;
    Ok(())
}

fn required_environment(name: &str) -> Result<String, Box<dyn std::error::Error>> {
    env::var(name).map_err(|_| format!("required environment variable is missing: {name}").into())
}
