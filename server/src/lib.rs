mod holidays;

use axum::{
    Json, Router,
    extract::State,
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sqlx::{PgPool, Row};
use std::{sync::Arc, time::Duration};
use uuid::Uuid;

#[derive(Clone)]
pub struct AppState {
    pub(crate) pool: PgPool,
    pub(crate) sync_token: Arc<str>,
    pub(crate) http: reqwest::Client,
}

impl AppState {
    pub fn new(pool: PgPool, sync_token: impl Into<Arc<str>>) -> Self {
        let http = reqwest::Client::builder()
            .timeout(Duration::from_secs(10))
            .user_agent("Waypoint/0.1")
            .build()
            .expect("the holiday HTTP client configuration is valid");
        Self {
            pool,
            sync_token: sync_token.into(),
            http,
        }
    }
}

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/v1/sync", post(sync))
        .route("/v1/holidays", get(holidays::list_holidays))
        .route(
            "/v1/holiday-preferences",
            get(holidays::get_preferences).put(holidays::put_preferences),
        )
        .route(
            "/v1/locations/municipalities",
            get(holidays::list_municipalities),
        )
        .with_state(state)
}

async fn health() -> Json<Value> {
    Json(json!({"status": "ready"}))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SyncRequest {
    device_id: String,
    cursor: i64,
    #[serde(default)]
    mutations: Vec<SyncMutation>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SyncMutation {
    mutation_id: String,
    task_id: String,
    operation: String,
    task: Value,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct SyncResponse {
    next_cursor: i64,
    accepted_mutation_ids: Vec<String>,
    changes: Vec<SyncChange>,
}

#[derive(Debug, Serialize)]
struct SyncChange {
    sequence: i64,
    operation: String,
    task: Value,
}

async fn sync(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(request): Json<SyncRequest>,
) -> Result<Json<SyncResponse>, ApiError> {
    authorize(&headers, &state.sync_token)?;
    validate_request(&request)?;

    let mut transaction = state.pool.begin().await.map_err(ApiError::database)?;
    let mut accepted_mutation_ids = Vec::with_capacity(request.mutations.len());

    for mutation in request.mutations {
        let mutation_id = Uuid::parse_str(&mutation.mutation_id).map_err(|_| {
            ApiError::bad_request(format!("invalid mutationId: {}", mutation.mutation_id))
        })?;
        let task_id = Uuid::parse_str(&mutation.task_id)
            .map_err(|_| ApiError::bad_request(format!("invalid taskId: {}", mutation.task_id)))?;

        let inserted = sqlx::query_scalar::<_, Uuid>(
            "INSERT INTO mutations(mutation_id, device_id) VALUES($1, $2) \
             ON CONFLICT(mutation_id) DO NOTHING RETURNING mutation_id",
        )
        .bind(mutation_id)
        .bind(&request.device_id)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(ApiError::database)?;

        accepted_mutation_ids.push(mutation.mutation_id.clone());
        if inserted.is_none() {
            continue;
        }

        let current_version =
            sqlx::query_scalar::<_, i64>("SELECT version FROM tasks WHERE id = $1 FOR UPDATE")
                .bind(task_id)
                .fetch_optional(&mut *transaction)
                .await
                .map_err(ApiError::database)?
                .unwrap_or(0);
        let server_version = current_version + 1;

        let mut task = mutation.task;
        task["id"] = Value::String(mutation.task_id.clone());
        task["version"] = Value::Number(server_version.into());
        let deleted = mutation.operation == "delete";

        sqlx::query(
            "INSERT INTO tasks(id, payload, version, deleted) VALUES($1, $2, $3, $4) \
             ON CONFLICT(id) DO UPDATE SET payload = excluded.payload, version = excluded.version, \
             deleted = excluded.deleted, updated_at = now()",
        )
        .bind(task_id)
        .bind(sqlx::types::Json(&task))
        .bind(server_version)
        .bind(deleted)
        .execute(&mut *transaction)
        .await
        .map_err(ApiError::database)?;

        sqlx::query("INSERT INTO changes(mutation_id, operation, task) VALUES($1, $2, $3)")
            .bind(mutation_id)
            .bind(&mutation.operation)
            .bind(sqlx::types::Json(&task))
            .execute(&mut *transaction)
            .await
            .map_err(ApiError::database)?;
    }

    let rows = sqlx::query(
        "SELECT sequence, operation, task FROM changes WHERE sequence > $1 ORDER BY sequence LIMIT 1000",
    )
    .bind(request.cursor)
    .fetch_all(&mut *transaction)
    .await
    .map_err(ApiError::database)?;

    let mut next_cursor = request.cursor;
    let mut changes = Vec::with_capacity(rows.len());
    for row in rows {
        let sequence: i64 = row.try_get("sequence").map_err(ApiError::database)?;
        let task: sqlx::types::Json<Value> = row.try_get("task").map_err(ApiError::database)?;
        next_cursor = sequence;
        changes.push(SyncChange {
            sequence,
            operation: row.try_get("operation").map_err(ApiError::database)?,
            task: task.0,
        });
    }

    transaction.commit().await.map_err(ApiError::database)?;
    Ok(Json(SyncResponse {
        next_cursor,
        accepted_mutation_ids,
        changes,
    }))
}

pub(crate) fn authorize(headers: &HeaderMap, expected_token: &str) -> Result<(), ApiError> {
    let supplied = headers
        .get(axum::http::header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "));
    if supplied == Some(expected_token) {
        return Ok(());
    }
    Err(ApiError::Unauthorized)
}

fn validate_request(request: &SyncRequest) -> Result<(), ApiError> {
    if request.cursor < 0 {
        return Err(ApiError::bad_request("cursor must be non-negative"));
    }
    if request.device_id.trim().is_empty() || request.device_id.len() > 128 {
        return Err(ApiError::bad_request(
            "deviceId must contain 1 to 128 characters",
        ));
    }
    if request.mutations.len() > 500 {
        return Err(ApiError::bad_request(
            "at most 500 mutations are accepted per sync",
        ));
    }
    for mutation in &request.mutations {
        validate_mutation(mutation)?;
    }
    Ok(())
}

fn validate_mutation(mutation: &SyncMutation) -> Result<(), ApiError> {
    if mutation.operation != "upsert" && mutation.operation != "delete" {
        return Err(ApiError::bad_request(format!(
            "invalid operation '{}' for mutation {}",
            mutation.operation, mutation.mutation_id
        )));
    }
    if mutation.task.get("id").and_then(Value::as_str) != Some(mutation.task_id.as_str()) {
        return Err(ApiError::bad_request(format!(
            "task.id must match taskId for mutation {}",
            mutation.mutation_id
        )));
    }
    if mutation.operation == "delete" {
        return Ok(());
    }

    let title = mutation
        .task
        .get("title")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if title.trim().is_empty() || title.chars().count() > 500 {
        return Err(ApiError::bad_request(format!(
            "task title must contain 1 to 500 characters for mutation {}",
            mutation.mutation_id
        )));
    }
    let scheduled_date = mutation
        .task
        .get("scheduledDate")
        .and_then(Value::as_str)
        .ok_or_else(|| ApiError::bad_request("task scheduledDate is required"))?;
    NaiveDate::parse_from_str(scheduled_date, "%Y-%m-%d")
        .map_err(|_| ApiError::bad_request(format!("invalid scheduledDate: {scheduled_date}")))?;
    Ok(())
}

#[derive(Debug)]
pub(crate) enum ApiError {
    Unauthorized,
    BadRequest(String),
    External(String),
    Internal(String),
}

impl ApiError {
    pub(crate) fn bad_request(message: impl Into<String>) -> Self {
        Self::BadRequest(message.into())
    }

    pub(crate) fn external(message: impl Into<String>) -> Self {
        Self::External(message.into())
    }

    pub(crate) fn database(error: sqlx::Error) -> Self {
        tracing::error!(error = %error, "database request failed");
        Self::Internal("database request failed".to_owned())
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            Self::Unauthorized => (StatusCode::UNAUTHORIZED, "unauthorized".to_owned()),
            Self::BadRequest(message) => (StatusCode::BAD_REQUEST, message),
            Self::External(message) => (StatusCode::SERVICE_UNAVAILABLE, message),
            Self::Internal(message) => (StatusCode::INTERNAL_SERVER_ERROR, message),
        };
        (status, Json(json!({"error": message}))).into_response()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{body::Body, http::Request};
    use sqlx::postgres::PgPoolOptions;
    use tower::ServiceExt;

    fn request_with(mutations: Vec<SyncMutation>) -> SyncRequest {
        SyncRequest {
            device_id: "test-device".to_owned(),
            cursor: 0,
            mutations,
        }
    }

    #[test]
    fn rejects_timestamp_instead_of_floating_date() {
        let mutation = SyncMutation {
            mutation_id: Uuid::new_v4().to_string(),
            task_id: Uuid::new_v4().to_string(),
            operation: "upsert".to_owned(),
            task: json!({}),
        };
        let mut mutation = mutation;
        mutation.task = json!({
            "id": mutation.task_id,
            "title": "Timezone invariant",
            "scheduledDate": "2026-09-01T00:00:00Z"
        });
        assert!(validate_request(&request_with(vec![mutation])).is_err());
    }

    #[test]
    fn accepts_valid_task_mutation() {
        let task_id = Uuid::new_v4().to_string();
        let mutation = SyncMutation {
            mutation_id: Uuid::new_v4().to_string(),
            task_id: task_id.clone(),
            operation: "upsert".to_owned(),
            task: json!({
                "id": task_id,
                "title": "Plan month",
                "scheduledDate": "2026-09-01"
            }),
        };
        assert!(validate_request(&request_with(vec![mutation])).is_ok());
    }
    #[tokio::test]
    async fn holiday_routes_require_bearer_token() {
        let pool = PgPoolOptions::new()
            .connect_lazy("postgres://waypoint:waypoint@127.0.0.1/waypoint")
            .expect("test database URL is valid");
        let app = router(AppState::new(pool, "expected-token"));

        for uri in [
            "/v1/holidays?from=2026-01-01&to=2026-12-31",
            "/v1/holiday-preferences",
            "/v1/locations/municipalities?state=SP",
        ] {
            let response = app
                .clone()
                .oneshot(Request::builder().uri(uri).body(Body::empty()).unwrap())
                .await
                .unwrap();
            assert_eq!(response.status(), StatusCode::UNAUTHORIZED, "{uri}");
        }
    }
}
