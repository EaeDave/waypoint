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
    let sync_token = validate_sync_token(required_environment("WAYPOINT_SYNC_TOKEN")?)?;
    let bind_address: SocketAddr = env::var("WAYPOINT_BIND")
        .unwrap_or_else(|_| "127.0.0.1:8787".to_owned())
        .parse()?;

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&database_url)
        .await?;
    sqlx::migrate!().run(&pool).await?;

    let listener = tokio::net::TcpListener::bind(bind_address).await?;
    let mut state = AppState::new(pool, sync_token);
    if let Some(service_account_json) = env::var("WAYPOINT_FIREBASE_SERVICE_ACCOUNT_JSON")
        .ok()
        .filter(|value| !value.trim().is_empty())
    {
        state = state.with_fcm_service_account_json(&service_account_json)?;
        tracing::info!("Firebase Cloud Messaging delivery is enabled");
    } else {
        tracing::warn!(
            "Firebase Cloud Messaging delivery is disabled; Android uses polling fallback"
        );
    }
    tracing::info!(address = %bind_address, "Waypoint API is ready");
    axum::serve(listener, router(state)).await?;
    Ok(())
}

fn required_environment(name: &str) -> Result<String, Box<dyn std::error::Error>> {
    env::var(name).map_err(|_| format!("required environment variable is missing: {name}").into())
}

fn validate_sync_token(token: String) -> Result<String, Box<dyn std::error::Error>> {
    if token.trim() != token || !(32..=512).contains(&token.len()) {
        return Err(
            "WAYPOINT_SYNC_TOKEN must contain 32 to 512 characters without surrounding whitespace"
                .into(),
        );
    }
    Ok(token)
}

#[cfg(test)]
mod tests {
    use super::validate_sync_token;

    #[test]
    fn accepts_high_entropy_sync_token() {
        let token = "a".repeat(64);
        assert_eq!(validate_sync_token(token.clone()).unwrap(), token);
    }

    #[test]
    fn rejects_short_sync_token() {
        assert!(validate_sync_token("too-short".to_owned()).is_err());
    }

    #[test]
    fn rejects_whitespace_bounded_sync_token() {
        assert!(validate_sync_token(format!(" {} ", "a".repeat(64))).is_err());
    }
}
