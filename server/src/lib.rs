mod holidays;

use axum::{
    Json, Router,
    extract::State,
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use chrono::{NaiveDate, NaiveTime};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sqlx::{PgPool, Row};
use std::{sync::Arc, time::Duration};
use unicode_segmentation::UnicodeSegmentation;
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
    entity_type: String,
    entity_id: String,
    operation: String,
    payload: Value,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct SyncResponse {
    next_cursor: i64,
    accepted_mutation_ids: Vec<String>,
    changes: Vec<SyncChange>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct SyncChange {
    sequence: i64,
    entity_type: String,
    entity_id: String,
    operation: String,
    payload: Value,
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
        let entity_type = mutation.entity_type.as_str();
        let entity_id = mutation.entity_id.as_str();

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

        let current_version = sqlx::query_scalar::<_, i64>(
            "SELECT version FROM sync_entities \
             WHERE entity_type = $1 AND entity_id = $2 FOR UPDATE",
        )
        .bind(entity_type)
        .bind(entity_id)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(ApiError::database)?
        .unwrap_or(0);
        let server_version = current_version + 1;

        let mut payload = mutation.payload;
        payload["version"] = Value::Number(server_version.into());
        let deleted = mutation.operation == "delete";

        sqlx::query(
            "INSERT INTO sync_entities \
             (entity_type, entity_id, payload, version, deleted) VALUES($1, $2, $3, $4, $5) \
             ON CONFLICT(entity_type, entity_id) DO UPDATE SET \
             payload = excluded.payload, version = excluded.version, \
             deleted = excluded.deleted, updated_at = now()",
        )
        .bind(entity_type)
        .bind(entity_id)
        .bind(sqlx::types::Json(&payload))
        .bind(server_version)
        .bind(deleted)
        .execute(&mut *transaction)
        .await
        .map_err(ApiError::database)?;

        sqlx::query(
            "INSERT INTO changes \
             (mutation_id, entity_type, entity_id, operation, payload) \
             VALUES($1, $2, $3, $4, $5)",
        )
        .bind(mutation_id)
        .bind(entity_type)
        .bind(entity_id)
        .bind(&mutation.operation)
        .bind(sqlx::types::Json(&payload))
        .execute(&mut *transaction)
        .await
        .map_err(ApiError::database)?;
    }

    let rows = sqlx::query(
        "SELECT sequence, entity_type, entity_id, operation, payload \
         FROM changes WHERE sequence > $1 ORDER BY sequence LIMIT 1000",
    )
    .bind(request.cursor)
    .fetch_all(&mut *transaction)
    .await
    .map_err(ApiError::database)?;

    let mut next_cursor = request.cursor;
    let mut changes = Vec::with_capacity(rows.len());
    for row in rows {
        let sequence: i64 = row.try_get("sequence").map_err(ApiError::database)?;
        let payload: sqlx::types::Json<Value> =
            row.try_get("payload").map_err(ApiError::database)?;
        next_cursor = sequence;
        changes.push(SyncChange {
            sequence,
            entity_type: row.try_get("entity_type").map_err(ApiError::database)?,
            entity_id: row.try_get("entity_id").map_err(ApiError::database)?,
            operation: row.try_get("operation").map_err(ApiError::database)?,
            payload: payload.0,
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
    if mutation.entity_id.is_empty() || mutation.entity_id.len() > 256 {
        return Err(ApiError::bad_request(
            "entityId must contain 1 to 256 characters",
        ));
    }
    match mutation.entity_type.as_str() {
        "task" => validate_task_mutation(mutation),
        "occurrence" => validate_occurrence_mutation(mutation),
        "habit" => validate_habit_mutation(mutation),
        "habit-entry" => validate_habit_entry_mutation(mutation),
        entity_type => Err(ApiError::bad_request(format!(
            "invalid entityType: {entity_type}"
        ))),
    }
}

fn validate_task_mutation(mutation: &SyncMutation) -> Result<(), ApiError> {
    Uuid::parse_str(&mutation.entity_id).map_err(|_| {
        ApiError::bad_request(format!("invalid task entityId: {}", mutation.entity_id))
    })?;
    if mutation.payload.get("id").and_then(Value::as_str) != Some(mutation.entity_id.as_str()) {
        return Err(ApiError::bad_request(format!(
            "task.id must match entityId for mutation {}",
            mutation.mutation_id
        )));
    }
    if mutation.operation == "delete" {
        return Ok(());
    }

    let title = mutation
        .payload
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
        .payload
        .get("scheduledDate")
        .and_then(Value::as_str)
        .ok_or_else(|| ApiError::bad_request("task scheduledDate is required"))?;
    NaiveDate::parse_from_str(scheduled_date, "%Y-%m-%d")
        .map_err(|_| ApiError::bad_request(format!("invalid scheduledDate: {scheduled_date}")))?;
    if let Some(scheduled_time) = mutation
        .payload
        .get("scheduledTime")
        .and_then(Value::as_str)
    {
        NaiveTime::parse_from_str(scheduled_time, "%H:%M").map_err(|_| {
            ApiError::bad_request(format!("invalid scheduledTime: {scheduled_time}"))
        })?;
    }
    if let Some(emoji_value) = mutation.payload.get("emoji") {
        let emoji = emoji_value
            .as_str()
            .ok_or_else(|| ApiError::bad_request("task emoji must be a string"))?;
        if emoji.chars().count() > 32 || emoji.trim() != emoji || emoji.graphemes(true).count() > 1
        {
            return Err(ApiError::bad_request(format!(
                "task emoji must be empty or contain one bounded grapheme for mutation {}",
                mutation.mutation_id
            )));
        }
    }
    if let Some(reminder_value) = mutation.payload.get("reminderMinutesBefore") {
        let reminders = reminder_value
            .as_array()
            .ok_or_else(|| ApiError::bad_request("task reminderMinutesBefore must be an array"))?;
        if reminders.len() > 5 {
            return Err(ApiError::bad_request("a task can have at most 5 reminders"));
        }
        let mut seen = Vec::with_capacity(reminders.len());
        for value in reminders {
            let minutes = value.as_u64().ok_or_else(|| {
                ApiError::bad_request("task reminder minutes must be non-negative integers")
            })?;
            if minutes > i32::MAX as u64 {
                return Err(ApiError::bad_request(
                    "task reminder minutes exceed the supported range",
                ));
            }
            if seen.contains(&minutes) {
                return Err(ApiError::bad_request(
                    "task reminders cannot contain duplicate times",
                ));
            }
            seen.push(minutes);
        }
    }

    let Some(recurrence) = mutation.payload.get("recurrence") else {
        return Ok(());
    };
    let frequency = recurrence
        .get("frequency")
        .and_then(Value::as_str)
        .unwrap_or("none");
    if !["none", "daily", "weekly", "monthly", "yearly"].contains(&frequency) {
        return Err(ApiError::bad_request("invalid recurrence frequency"));
    }
    let interval = recurrence
        .get("interval")
        .and_then(Value::as_i64)
        .unwrap_or(1);
    if interval < 1 {
        return Err(ApiError::bad_request(
            "recurrence interval must be greater than zero",
        ));
    }
    let end_mode = recurrence
        .get("endMode")
        .and_then(Value::as_str)
        .unwrap_or("never");
    if !["never", "onDate", "afterCount"].contains(&end_mode) {
        return Err(ApiError::bad_request("invalid recurrence endMode"));
    }
    if end_mode == "onDate" {
        let until_date = recurrence
            .get("untilDate")
            .and_then(Value::as_str)
            .ok_or_else(|| ApiError::bad_request("recurrence untilDate is required"))?;
        NaiveDate::parse_from_str(until_date, "%Y-%m-%d")
            .map_err(|_| ApiError::bad_request(format!("invalid untilDate: {until_date}")))?;
    }
    if end_mode == "afterCount"
        && recurrence
            .get("occurrenceCount")
            .and_then(Value::as_i64)
            .unwrap_or_default()
            < 1
    {
        return Err(ApiError::bad_request(
            "recurrence occurrenceCount must be greater than zero",
        ));
    }
    if frequency == "weekly" {
        let weekdays = recurrence
            .get("weekdays")
            .and_then(Value::as_array)
            .ok_or_else(|| ApiError::bad_request("weekly recurrence weekdays must be an array"))?;
        let mut seen = [false; 7];
        for value in weekdays {
            let weekday = value
                .as_u64()
                .ok_or_else(|| ApiError::bad_request("invalid recurrence weekday"))?;
            if !(1..=7).contains(&weekday) || seen[weekday as usize - 1] {
                return Err(ApiError::bad_request(
                    "invalid or duplicate recurrence weekday",
                ));
            }
            seen[weekday as usize - 1] = true;
        }
    }
    Ok(())
}

fn validate_occurrence_mutation(mutation: &SyncMutation) -> Result<(), ApiError> {
    let task_id = mutation
        .payload
        .get("taskId")
        .and_then(Value::as_str)
        .ok_or_else(|| ApiError::bad_request("occurrence taskId is required"))?;
    Uuid::parse_str(task_id)
        .map_err(|_| ApiError::bad_request(format!("invalid occurrence taskId: {task_id}")))?;
    let occurrence_date = mutation
        .payload
        .get("occurrenceDate")
        .and_then(Value::as_str)
        .ok_or_else(|| ApiError::bad_request("occurrenceDate is required"))?;
    NaiveDate::parse_from_str(occurrence_date, "%Y-%m-%d")
        .map_err(|_| ApiError::bad_request(format!("invalid occurrenceDate: {occurrence_date}")))?;
    if mutation.entity_id != format!("{task_id}@{occurrence_date}") {
        return Err(ApiError::bad_request(
            "occurrence entityId must match taskId and occurrenceDate",
        ));
    }
    if mutation.operation == "delete" {
        return Ok(());
    }
    let status = mutation
        .payload
        .get("status")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if !["pending", "completed", "skipped"].contains(&status) {
        return Err(ApiError::bad_request("invalid occurrence status"));
    }
    Ok(())
}

fn validate_habit_mutation(mutation: &SyncMutation) -> Result<(), ApiError> {
    Uuid::parse_str(&mutation.entity_id).map_err(|_| {
        ApiError::bad_request(format!("invalid habit entityId: {}", mutation.entity_id))
    })?;
    if mutation.payload.get("id").and_then(Value::as_str) != Some(mutation.entity_id.as_str()) {
        return Err(ApiError::bad_request(format!(
            "habit.id must match entityId for mutation {}",
            mutation.mutation_id
        )));
    }
    if mutation.operation == "delete" {
        return Ok(());
    }

    let title = mutation
        .payload
        .get("title")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if title.trim().is_empty() || title.chars().count() > 500 {
        return Err(ApiError::bad_request(
            "habit title must contain 1 to 500 characters",
        ));
    }
    let target = mutation
        .payload
        .get("targetAmount")
        .and_then(Value::as_i64)
        .unwrap_or_default();
    if !(1..=1_000_000_000).contains(&target) {
        return Err(ApiError::bad_request(
            "habit targetAmount must be between 1 and 1000000000",
        ));
    }
    let unit = mutation
        .payload
        .get("unit")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if unit.trim() != unit || unit.chars().count() > 32 || unit.contains(['\n', '\r']) {
        return Err(ApiError::bad_request(
            "habit unit must be a trimmed single line of at most 32 characters",
        ));
    }
    let mode = mutation
        .payload
        .get("checkInMode")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if !["fixed", "manual", "complete"].contains(&mode) {
        return Err(ApiError::bad_request("invalid habit checkInMode"));
    }
    let increment = mutation
        .payload
        .get("incrementAmount")
        .and_then(Value::as_i64)
        .unwrap_or_default();
    if !(1..=1_000_000_000).contains(&increment) || (mode == "fixed" && increment > target) {
        return Err(ApiError::bad_request("invalid habit incrementAmount"));
    }

    let weekdays = mutation
        .payload
        .get("weekdays")
        .and_then(Value::as_array)
        .ok_or_else(|| ApiError::bad_request("habit weekdays must be an array"))?;
    if weekdays.is_empty() || weekdays.len() > 7 {
        return Err(ApiError::bad_request(
            "habit must have between 1 and 7 weekdays",
        ));
    }
    let mut seen_weekdays = [false; 7];
    for value in weekdays {
        let weekday = value
            .as_u64()
            .ok_or_else(|| ApiError::bad_request("invalid habit weekday"))?;
        if !(1..=7).contains(&weekday) || seen_weekdays[weekday as usize - 1] {
            return Err(ApiError::bad_request(
                "habit weekdays must be unique values from 1 to 7",
            ));
        }
        seen_weekdays[weekday as usize - 1] = true;
    }

    let reminders = mutation
        .payload
        .get("reminderTimes")
        .and_then(Value::as_array)
        .ok_or_else(|| ApiError::bad_request("habit reminderTimes must be an array"))?;
    if reminders.len() > 10 {
        return Err(ApiError::bad_request(
            "a habit can have at most 10 reminder times",
        ));
    }
    let mut seen_reminders = Vec::with_capacity(reminders.len());
    for value in reminders {
        let reminder = value
            .as_str()
            .ok_or_else(|| ApiError::bad_request("habit reminder time must be a string"))?;
        NaiveTime::parse_from_str(reminder, "%H:%M").map_err(|_| {
            ApiError::bad_request(format!("invalid habit reminder time: {reminder}"))
        })?;
        if seen_reminders.contains(&reminder) {
            return Err(ApiError::bad_request(
                "habit reminder times cannot contain duplicates",
            ));
        }
        seen_reminders.push(reminder);
    }

    let emoji = mutation
        .payload
        .get("emoji")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if emoji.chars().count() > 32 || emoji.trim() != emoji || emoji.graphemes(true).count() > 1 {
        return Err(ApiError::bad_request(
            "habit emoji must be empty or contain one bounded grapheme",
        ));
    }
    Ok(())
}

fn validate_habit_entry_mutation(mutation: &SyncMutation) -> Result<(), ApiError> {
    Uuid::parse_str(&mutation.entity_id).map_err(|_| {
        ApiError::bad_request(format!(
            "invalid habit entry entityId: {}",
            mutation.entity_id
        ))
    })?;
    if mutation.payload.get("id").and_then(Value::as_str) != Some(mutation.entity_id.as_str()) {
        return Err(ApiError::bad_request(format!(
            "habit entry id must match entityId for mutation {}",
            mutation.mutation_id
        )));
    }
    let habit_id = mutation
        .payload
        .get("habitId")
        .and_then(Value::as_str)
        .ok_or_else(|| ApiError::bad_request("habit entry habitId is required"))?;
    Uuid::parse_str(habit_id)
        .map_err(|_| ApiError::bad_request(format!("invalid habit entry habitId: {habit_id}")))?;
    let entry_date = mutation
        .payload
        .get("entryDate")
        .and_then(Value::as_str)
        .ok_or_else(|| ApiError::bad_request("habit entryDate is required"))?;
    NaiveDate::parse_from_str(entry_date, "%Y-%m-%d")
        .map_err(|_| ApiError::bad_request(format!("invalid habit entryDate: {entry_date}")))?;
    if mutation.operation == "delete" {
        return Ok(());
    }
    let amount = mutation
        .payload
        .get("amount")
        .and_then(Value::as_i64)
        .unwrap_or_default();
    if !(1..=1_000_000_000).contains(&amount) {
        return Err(ApiError::bad_request(
            "habit entry amount must be between 1 and 1000000000",
        ));
    }
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
        let task_id = Uuid::new_v4().to_string();
        let mutation = SyncMutation {
            mutation_id: Uuid::new_v4().to_string(),
            entity_type: "task".to_owned(),
            entity_id: task_id.clone(),
            operation: "upsert".to_owned(),
            payload: json!({
                "id": task_id,
                "title": "Timezone invariant",
                "scheduledDate": "2026-09-01T00:00:00Z"
            }),
        };
        assert!(validate_request(&request_with(vec![mutation])).is_err());
    }
    #[test]
    fn rejects_timestamp_instead_of_floating_time() {
        let task_id = Uuid::new_v4().to_string();
        let mutation = SyncMutation {
            mutation_id: Uuid::new_v4().to_string(),
            entity_type: "task".to_owned(),
            entity_id: task_id.clone(),
            operation: "upsert".to_owned(),
            payload: json!({
                "id": task_id,
                "title": "Timezone invariant",
                "scheduledDate": "2026-09-01",
                "scheduledTime": "09:30:00Z"
            }),
        };
        assert!(validate_request(&request_with(vec![mutation])).is_err());
    }

    #[test]
    fn accepts_valid_task_mutation() {
        let task_id = Uuid::new_v4().to_string();
        let mutation = SyncMutation {
            mutation_id: Uuid::new_v4().to_string(),
            entity_type: "task".to_owned(),
            entity_id: task_id.clone(),
            operation: "upsert".to_owned(),
            payload: json!({
                "id": task_id,
                "title": "Plan month",
                "scheduledDate": "2026-09-01",
                "scheduledTime": "09:30",
                "reminderMinutesBefore": [300, 180, 60, 30, 0],
                "recurrence": {
                    "frequency": "weekly",
                    "interval": 2,
                    "weekdays": [1, 4],
                    "endMode": "afterCount",
                    "occurrenceCount": 12
                }
            }),
        };
        assert!(validate_request(&request_with(vec![mutation])).is_ok());
    }

    #[test]
    fn rejects_invalid_task_reminder_lists() {
        for reminders in [
            json!([360, 300, 180, 60, 30, 0]),
            json!([30, 30]),
            json!([-1]),
        ] {
            let task_id = Uuid::new_v4().to_string();
            let mutation = SyncMutation {
                mutation_id: Uuid::new_v4().to_string(),
                entity_type: "task".to_owned(),
                entity_id: task_id.clone(),
                operation: "upsert".to_owned(),
                payload: json!({
                    "id": task_id,
                    "title": "Invalid reminders",
                    "scheduledDate": "2026-09-01",
                    "reminderMinutesBefore": reminders
                }),
            };
            assert!(validate_request(&request_with(vec![mutation])).is_err());
        }
    }

    #[test]
    fn accepts_compound_emoji_and_legacy_task_without_emoji() {
        for emoji in [Some("👨‍💻"), None] {
            let task_id = Uuid::new_v4().to_string();
            let mut payload = json!({
                "id": task_id,
                "title": "Preserve emoji",
                "scheduledDate": "2026-09-01"
            });
            if let Some(value) = emoji {
                payload["emoji"] = Value::String(value.to_owned());
            }
            let mutation = SyncMutation {
                mutation_id: Uuid::new_v4().to_string(),
                entity_type: "task".to_owned(),
                entity_id: task_id,
                operation: "upsert".to_owned(),
                payload,
            };
            assert!(validate_request(&request_with(vec![mutation])).is_ok());
        }
    }

    #[test]
    fn rejects_multiple_emoji_graphemes() {
        let task_id = Uuid::new_v4().to_string();
        let mutation = SyncMutation {
            mutation_id: Uuid::new_v4().to_string(),
            entity_type: "task".to_owned(),
            entity_id: task_id.clone(),
            operation: "upsert".to_owned(),
            payload: json!({
                "id": task_id,
                "title": "Too many emoji",
                "scheduledDate": "2026-09-01",
                "emoji": "😀🚀"
            }),
        };
        assert!(validate_request(&request_with(vec![mutation])).is_err());
    }
    #[test]
    fn accepts_occurrence_mutation_with_composite_identity() {
        let task_id = Uuid::new_v4().to_string();
        let occurrence_date = "2026-09-01";
        let mutation = SyncMutation {
            mutation_id: Uuid::new_v4().to_string(),
            entity_type: "occurrence".to_owned(),
            entity_id: format!("{task_id}@{occurrence_date}"),
            operation: "upsert".to_owned(),
            payload: json!({
                "taskId": task_id,
                "occurrenceDate": occurrence_date,
                "status": "completed"
            }),
        };
        assert!(validate_request(&request_with(vec![mutation])).is_ok());
    }
    #[test]
    fn accepts_habit_and_entry_mutations() {
        let habit_id = Uuid::new_v4().to_string();
        let entry_id = Uuid::new_v4().to_string();
        let habit = SyncMutation {
            mutation_id: Uuid::new_v4().to_string(),
            entity_type: "habit".to_owned(),
            entity_id: habit_id.clone(),
            operation: "upsert".to_owned(),
            payload: json!({
                "id": habit_id,
                "title": "Água",
                "targetAmount": 2000,
                "unit": "ml",
                "checkInMode": "fixed",
                "incrementAmount": 250,
                "weekdays": [1, 2, 3, 4, 5, 6, 7],
                "reminderTimes": ["08:00", "12:00", "18:00"],
                "emoji": "💧"
            }),
        };
        let entry = SyncMutation {
            mutation_id: Uuid::new_v4().to_string(),
            entity_type: "habit-entry".to_owned(),
            entity_id: entry_id.clone(),
            operation: "upsert".to_owned(),
            payload: json!({
                "id": entry_id,
                "habitId": habit_id,
                "entryDate": "2026-09-01",
                "amount": 250
            }),
        };
        assert!(validate_request(&request_with(vec![habit, entry])).is_ok());
    }

    #[test]
    fn rejects_invalid_habit_schedules_and_amounts() {
        for payload in [
            json!({
                "title": "Duplicated day",
                "targetAmount": 1,
                "unit": "",
                "checkInMode": "complete",
                "incrementAmount": 1,
                "weekdays": [1, 1],
                "reminderTimes": []
            }),
            json!({
                "title": "Too many reminders",
                "targetAmount": 1,
                "unit": "",
                "checkInMode": "complete",
                "incrementAmount": 1,
                "weekdays": [1],
                "reminderTimes": [
                    "01:00", "02:00", "03:00", "04:00", "05:00", "06:00",
                    "07:00", "08:00", "09:00", "10:00", "11:00"
                ]
            }),
        ] {
            let habit_id = Uuid::new_v4().to_string();
            let mut payload = payload;
            payload["id"] = Value::String(habit_id.clone());
            let mutation = SyncMutation {
                mutation_id: Uuid::new_v4().to_string(),
                entity_type: "habit".to_owned(),
                entity_id: habit_id,
                operation: "upsert".to_owned(),
                payload,
            };
            assert!(validate_request(&request_with(vec![mutation])).is_err());
        }

        let entry_id = Uuid::new_v4().to_string();
        let entry = SyncMutation {
            mutation_id: Uuid::new_v4().to_string(),
            entity_type: "habit-entry".to_owned(),
            entity_id: entry_id.clone(),
            operation: "upsert".to_owned(),
            payload: json!({
                "id": entry_id,
                "habitId": Uuid::new_v4().to_string(),
                "entryDate": "2026-09-01T00:00:00Z",
                "amount": 0
            }),
        };
        assert!(validate_request(&request_with(vec![entry])).is_err());
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
