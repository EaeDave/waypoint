use jsonwebtoken::{Algorithm, EncodingKey, Header, encode};
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{
    sync::Arc,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};
use tokio::sync::Mutex;

const FCM_SCOPE: &str = "https://www.googleapis.com/auth/firebase.messaging";
const DEFAULT_TOKEN_URI: &str = "https://oauth2.googleapis.com/token";

#[derive(Clone)]
pub struct FcmClient {
    inner: Arc<FcmClientInner>,
}

struct FcmClientInner {
    http: reqwest::Client,
    project_id: String,
    client_email: String,
    token_uri: String,
    encoding_key: EncodingKey,
    access_token: Mutex<Option<CachedAccessToken>>,
}

struct CachedAccessToken {
    value: String,
    refresh_at: Instant,
}

#[derive(Debug, Deserialize)]
struct ServiceAccount {
    project_id: String,
    client_email: String,
    private_key: String,
    #[serde(default = "default_token_uri")]
    token_uri: String,
}

#[derive(Serialize)]
struct TokenClaims<'a> {
    iss: &'a str,
    scope: &'a str,
    aud: &'a str,
    iat: u64,
    exp: u64,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: u64,
}

#[derive(Debug)]
pub enum FcmError {
    InvalidConfiguration(String),
    Authentication(String),
    Delivery { status: StatusCode, message: String },
}

impl std::fmt::Display for FcmError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidConfiguration(message) => write!(formatter, "{message}"),
            Self::Authentication(message) => write!(formatter, "{message}"),
            Self::Delivery { status, message } => {
                write!(formatter, "FCM delivery failed with {status}: {message}")
            }
        }
    }
}

impl std::error::Error for FcmError {}

impl FcmError {
    pub fn invalid_device_token(&self) -> bool {
        match self {
            Self::Delivery { status, message } => {
                *status == StatusCode::NOT_FOUND
                    || message.contains("UNREGISTERED")
                    || message.contains("INVALID_ARGUMENT")
            }
            _ => false,
        }
    }
}

impl FcmClient {
    pub fn from_service_account_json(
        http: reqwest::Client,
        service_account_json: &str,
    ) -> Result<Self, FcmError> {
        let account: ServiceAccount =
            serde_json::from_str(service_account_json).map_err(|error| {
                FcmError::InvalidConfiguration(format!(
                    "invalid Firebase service account JSON: {error}"
                ))
            })?;
        if account.project_id.trim().is_empty() || account.client_email.trim().is_empty() {
            return Err(FcmError::InvalidConfiguration(
                "Firebase service account project_id and client_email are required".to_owned(),
            ));
        }
        let encoding_key =
            EncodingKey::from_rsa_pem(account.private_key.as_bytes()).map_err(|error| {
                FcmError::InvalidConfiguration(format!(
                    "invalid Firebase service account private_key: {error}"
                ))
            })?;

        Ok(Self {
            inner: Arc::new(FcmClientInner {
                http,
                project_id: account.project_id,
                client_email: account.client_email,
                token_uri: account.token_uri,
                encoding_key,
                access_token: Mutex::new(None),
            }),
        })
    }

    pub async fn send_sync_needed(&self, push_token: &str, sequence: i64) -> Result<(), FcmError> {
        let access_token = self.access_token().await?;
        let url = format!(
            "https://fcm.googleapis.com/v1/projects/{}/messages:send",
            self.inner.project_id
        );
        let response = self
            .inner
            .http
            .post(url)
            .bearer_auth(access_token)
            .json(&sync_message(push_token, sequence))
            .send()
            .await
            .map_err(|error| FcmError::Delivery {
                status: StatusCode::SERVICE_UNAVAILABLE,
                message: error.to_string(),
            })?;
        if response.status().is_success() {
            return Ok(());
        }

        let status = response.status();
        let message = response
            .text()
            .await
            .unwrap_or_else(|error| error.to_string());
        Err(FcmError::Delivery { status, message })
    }

    async fn access_token(&self) -> Result<String, FcmError> {
        let mut cached = self.inner.access_token.lock().await;
        if let Some(token) = cached.as_ref()
            && Instant::now() < token.refresh_at
        {
            return Ok(token.value.clone());
        }

        let issued_at = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|error| FcmError::Authentication(error.to_string()))?
            .as_secs();
        let claims = TokenClaims {
            iss: &self.inner.client_email,
            scope: FCM_SCOPE,
            aud: &self.inner.token_uri,
            iat: issued_at,
            exp: issued_at + 3600,
        };
        let assertion = encode(
            &Header::new(Algorithm::RS256),
            &claims,
            &self.inner.encoding_key,
        )
        .map_err(|error| FcmError::Authentication(error.to_string()))?;
        let response = self
            .inner
            .http
            .post(&self.inner.token_uri)
            .form(&[
                ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
                ("assertion", assertion.as_str()),
            ])
            .send()
            .await
            .map_err(|error| FcmError::Authentication(error.to_string()))?;
        let status = response.status();
        if !status.is_success() {
            let message = response
                .text()
                .await
                .unwrap_or_else(|error| error.to_string());
            return Err(FcmError::Authentication(format!(
                "OAuth token request failed with {status}: {message}"
            )));
        }
        let response: TokenResponse = response
            .json()
            .await
            .map_err(|error| FcmError::Authentication(error.to_string()))?;
        let refresh_after = response.expires_in.saturating_sub(60).max(1);
        let value = response.access_token;
        *cached = Some(CachedAccessToken {
            value: value.clone(),
            refresh_at: Instant::now() + Duration::from_secs(refresh_after),
        });
        Ok(value)
    }
}

fn default_token_uri() -> String {
    DEFAULT_TOKEN_URI.to_owned()
}

fn sync_message(push_token: &str, sequence: i64) -> Value {
    json!({
        "message": {
            "token": push_token,
            "data": {
                "type": "sync-needed",
                "sequence": sequence.to_string()
            },
            "android": {
                "priority": "high",
                "collapse_key": "waypoint-sync"
            }
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sync_message_contains_only_a_collapsible_hint() {
        let message = sync_message("device-token", 42);
        assert_eq!(message["message"]["token"], "device-token");
        assert_eq!(message["message"]["data"]["type"], "sync-needed");
        assert_eq!(message["message"]["data"]["sequence"], "42");
        assert_eq!(message["message"]["android"]["priority"], "high");
        assert_eq!(
            message["message"]["android"]["collapse_key"],
            "waypoint-sync"
        );
        assert!(message["message"].get("notification").is_none());
    }
}
