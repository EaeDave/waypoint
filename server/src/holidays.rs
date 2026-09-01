use crate::{ApiError, AppState, authorize};
use axum::{
    Json,
    extract::{Query, State},
    http::HeaderMap,
};
use chrono::{Datelike, Duration, NaiveDate};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use std::cmp::Reverse;
use std::collections::BTreeMap;

const FERIADOS_BRASIL_BASE_URL: &str =
    "https://raw.githubusercontent.com/joaopbini/feriados-brasil/master/dados";
const VALID_STATE_CODES: [&str; 27] = [
    "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA", "PB", "PR",
    "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
];

#[derive(Clone, Copy)]
struct SourceDefinition {
    name: &'static str,
    path: &'static str,
    expected_type: &'static str,
    kind: &'static str,
    scope: &'static str,
}

const SOURCES: [SourceDefinition; 5] = [
    SourceDefinition {
        name: "feriados-brasil-national",
        path: "feriados/nacional/json",
        expected_type: "NACIONAL",
        kind: "legal",
        scope: "national",
    },
    SourceDefinition {
        name: "feriados-brasil-state",
        path: "feriados/estadual/json",
        expected_type: "ESTADUAL",
        kind: "legal",
        scope: "state",
    },
    SourceDefinition {
        name: "feriados-brasil-municipal",
        path: "feriados/municipal/json",
        expected_type: "MUNICIPAL",
        kind: "legal",
        scope: "municipal",
    },
    SourceDefinition {
        name: "feriados-brasil-facultative",
        path: "feriados/facultativo/json",
        expected_type: "FACULTATIVO",
        kind: "optional",
        scope: "dynamic",
    },
    SourceDefinition {
        name: "feriados-brasil-commemorative",
        path: "comemorativas/json",
        expected_type: "COMEMORATIVA",
        kind: "commemorative",
        scope: "national",
    },
];

#[derive(Debug, Deserialize)]
struct RawHoliday {
    #[serde(default)]
    id: Option<String>,
    data: String,
    nome: String,
    tipo: String,
    #[serde(default)]
    descricao: Option<String>,
    #[serde(default)]
    uf: Option<String>,
    #[serde(default)]
    codigo_ibge: Option<i64>,
}

#[derive(Debug, Clone)]
struct NormalizedHoliday {
    source_key: String,
    date: String,
    year: i32,
    name: String,
    description: Option<String>,
    kind: &'static str,
    scope: &'static str,
    state_code: Option<String>,
    city_code: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct HolidayPreferences {
    state_code: Option<String>,
    city_code: Option<String>,
    include_national: bool,
    include_state: bool,
    include_municipal: bool,
    include_commemorative: bool,
    include_optional: bool,
    revision: i64,
    updated_at: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct HolidayPreferencesInput {
    state_code: Option<String>,
    city_code: Option<String>,
    include_national: bool,
    include_state: bool,
    include_municipal: bool,
    include_commemorative: bool,
    include_optional: bool,
}

#[derive(Debug, Deserialize)]
pub(crate) struct HolidayRangeQuery {
    from: String,
    to: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct MunicipalityQuery {
    state: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct HolidayDto {
    date: String,
    name: String,
    description: Option<String>,
    kind: String,
    scope: String,
    state_code: Option<String>,
    city_code: Option<String>,
    source: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CoverageDto {
    source: String,
    year: i32,
    status: String,
    fetched_at: Option<String>,
    last_error: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct HolidayRangeResponse {
    holidays: Vec<HolidayDto>,
    coverage: Vec<CoverageDto>,
    complete: bool,
}

#[derive(Debug, Deserialize)]
struct IbgeMunicipality {
    id: i64,
    nome: String,
}

#[derive(Debug, Serialize)]
pub(crate) struct MunicipalityDto {
    code: String,
    name: String,
}

pub(crate) async fn get_preferences(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<HolidayPreferences>, ApiError> {
    authorize(&headers, &state.sync_token)?;
    Ok(Json(load_preferences(&state).await?))
}

pub(crate) async fn put_preferences(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(input): Json<HolidayPreferencesInput>,
) -> Result<Json<HolidayPreferences>, ApiError> {
    authorize(&headers, &state.sync_token)?;
    let input = normalize_preferences(input)?;
    if let (Some(state_code), Some(city_code)) = (&input.state_code, &input.city_code) {
        ensure_municipalities(&state, state_code).await?;
        let belongs_to_state = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM brazil_municipalities WHERE city_code = $1 AND state_code = $2)",
        )
        .bind(city_code)
        .bind(state_code)
        .fetch_one(&state.pool)
        .await
        .map_err(ApiError::database)?;
        if !belongs_to_state {
            return Err(ApiError::bad_request(format!(
                "municipality {city_code} does not belong to state {state_code}"
            )));
        }
    }

    sqlx::query(
        "UPDATE holiday_preferences SET state_code = $1, city_code = $2, include_national = $3, \
         include_state = $4, include_municipal = $5, include_commemorative = $6, include_optional = $7, \
         revision = revision + 1, updated_at = now() WHERE singleton = TRUE",
    )
    .bind(&input.state_code)
    .bind(&input.city_code)
    .bind(input.include_national)
    .bind(input.include_state)
    .bind(input.include_municipal)
    .bind(input.include_commemorative)
    .bind(input.include_optional)
    .execute(&state.pool)
    .await
    .map_err(ApiError::database)?;

    Ok(Json(load_preferences(&state).await?))
}

pub(crate) async fn list_municipalities(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<MunicipalityQuery>,
) -> Result<Json<Vec<MunicipalityDto>>, ApiError> {
    authorize(&headers, &state.sync_token)?;
    let state_code = normalize_state_code(Some(query.state))?
        .ok_or_else(|| ApiError::bad_request("state is required"))?;
    ensure_municipalities(&state, &state_code).await?;

    let rows = sqlx::query(
        "SELECT city_code, name FROM brazil_municipalities WHERE state_code = $1 ORDER BY name",
    )
    .bind(&state_code)
    .fetch_all(&state.pool)
    .await
    .map_err(ApiError::database)?;
    let municipalities = rows
        .into_iter()
        .map(|row| MunicipalityDto {
            code: row.get("city_code"),
            name: row.get("name"),
        })
        .collect();
    Ok(Json(municipalities))
}

pub(crate) async fn list_holidays(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<HolidayRangeQuery>,
) -> Result<Json<HolidayRangeResponse>, ApiError> {
    authorize(&headers, &state.sync_token)?;
    let (from, to) = validate_range(&query)?;
    for year in from.year()..=to.year() {
        ensure_year(&state, year).await;
    }

    let preferences = load_preferences(&state).await?;
    let rows = sqlx::query(
        "SELECT holiday_date::text AS holiday_date, name, description, kind, scope_level, \
         trim(state_code) AS state_code, city_code, source FROM holiday_entries \
         WHERE holiday_date BETWEEN $1::date AND $2::date ORDER BY holiday_date, kind, scope_level, name",
    )
    .bind(from.to_string())
    .bind(to.to_string())
    .fetch_all(&state.pool)
    .await
    .map_err(ApiError::database)?;

    let mut holidays: Vec<HolidayDto> = rows
        .into_iter()
        .filter_map(|row| {
            let kind: String = row.get("kind");
            let scope: String = row.get("scope_level");
            let state_code: Option<String> = row.get("state_code");
            let city_code: Option<String> = row.get("city_code");
            let visible = match (kind.as_str(), scope.as_str()) {
                ("commemorative", _) => preferences.include_commemorative,
                ("optional", "national") => preferences.include_optional,
                ("optional", "state") => {
                    preferences.include_optional && state_code == preferences.state_code
                }
                ("optional", "municipal") => {
                    preferences.include_optional && city_code == preferences.city_code
                }
                ("legal", "national") => preferences.include_national,
                ("legal", "state") => {
                    preferences.include_state && state_code == preferences.state_code
                }
                ("legal", "municipal") => {
                    preferences.include_municipal && city_code == preferences.city_code
                }
                _ => false,
            };
            visible.then(|| HolidayDto {
                date: row.get("holiday_date"),
                name: row.get("name"),
                description: row.get("description"),
                kind,
                scope,
                state_code,
                city_code,
                source: row.get("source"),
            })
        })
        .collect();
    holidays.extend(recurring_legal_events(&preferences, from, to));
    let holidays = deduplicate_holidays(holidays);

    let coverage_rows = sqlx::query(
        "SELECT source, holiday_year, status, \
         CASE WHEN fetched_at IS NULL THEN NULL ELSE to_char(fetched_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') END AS fetched_at, \
         last_error FROM holiday_source_snapshots WHERE holiday_year BETWEEN $1 AND $2 \
         ORDER BY holiday_year, source",
    )
    .bind(from.year())
    .bind(to.year())
    .fetch_all(&state.pool)
    .await
    .map_err(ApiError::database)?;
    let coverage: Vec<CoverageDto> = coverage_rows
        .into_iter()
        .map(|row| CoverageDto {
            source: row.get("source"),
            year: row.get("holiday_year"),
            status: row.get("status"),
            fetched_at: row.get("fetched_at"),
            last_error: row.get("last_error"),
        })
        .collect();
    let complete = coverage_is_complete(&coverage, from.year(), to.year());

    Ok(Json(HolidayRangeResponse {
        holidays,
        coverage,
        complete,
    }))
}

async fn load_preferences(state: &AppState) -> Result<HolidayPreferences, ApiError> {
    let row = sqlx::query(
        "SELECT trim(state_code) AS state_code, city_code, include_national, include_state, \
         include_municipal, include_commemorative, include_optional, revision, \
         to_char(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS updated_at \
         FROM holiday_preferences WHERE singleton = TRUE",
    )
    .fetch_one(&state.pool)
    .await
    .map_err(ApiError::database)?;
    Ok(HolidayPreferences {
        state_code: row.get("state_code"),
        city_code: row.get("city_code"),
        include_national: row.get("include_national"),
        include_state: row.get("include_state"),
        include_municipal: row.get("include_municipal"),
        include_commemorative: row.get("include_commemorative"),
        include_optional: row.get("include_optional"),
        revision: row.get("revision"),
        updated_at: row.get("updated_at"),
    })
}

fn normalize_preferences(
    mut input: HolidayPreferencesInput,
) -> Result<HolidayPreferencesInput, ApiError> {
    input.state_code = normalize_state_code(input.state_code)?;
    input.city_code = input.city_code.and_then(|value| {
        let trimmed = value.trim().to_owned();
        (!trimmed.is_empty()).then_some(trimmed)
    });
    if input.city_code.is_some() && input.state_code.is_none() {
        return Err(ApiError::bad_request(
            "cityCode requires a selected stateCode",
        ));
    }
    if input.state_code.is_none() {
        input.city_code = None;
    }
    Ok(input)
}

fn normalize_state_code(value: Option<String>) -> Result<Option<String>, ApiError> {
    let Some(value) = value else {
        return Ok(None);
    };
    let normalized = value.trim().to_ascii_uppercase();
    if normalized.is_empty() {
        return Ok(None);
    }
    if !VALID_STATE_CODES.contains(&normalized.as_str()) {
        return Err(ApiError::bad_request(format!(
            "invalid Brazilian state code: {normalized}"
        )));
    }
    Ok(Some(normalized))
}

fn validate_range(query: &HolidayRangeQuery) -> Result<(NaiveDate, NaiveDate), ApiError> {
    let from = NaiveDate::parse_from_str(&query.from, "%Y-%m-%d")
        .map_err(|_| ApiError::bad_request(format!("invalid from date: {}", query.from)))?;
    let to = NaiveDate::parse_from_str(&query.to, "%Y-%m-%d")
        .map_err(|_| ApiError::bad_request(format!("invalid to date: {}", query.to)))?;
    let days = (to - from).num_days();
    if !(0..=400).contains(&days) {
        return Err(ApiError::bad_request(
            "holiday range must be ordered and contain at most 401 days",
        ));
    }
    Ok((from, to))
}
fn recurring_legal_events(
    preferences: &HolidayPreferences,
    from: NaiveDate,
    to: NaiveDate,
) -> Vec<HolidayDto> {
    let mut events = Vec::new();
    let mut add_event = |date: NaiveDate,
                         name: &str,
                         description: &str,
                         scope: &str,
                         state_code: Option<&str>,
                         city_code: Option<&str>,
                         source: &str| {
        if (from..=to).contains(&date) {
            events.push(HolidayDto {
                date: date.to_string(),
                name: name.to_owned(),
                description: Some(description.to_owned()),
                kind: "legal".to_owned(),
                scope: scope.to_owned(),
                state_code: state_code.map(str::to_owned),
                city_code: city_code.map(str::to_owned),
                source: source.to_owned(),
            });
        }
    };

    for year in from.year()..=to.year() {
        if preferences.include_national {
            for (month, day, name) in [
                (1, 1, "Ano Novo"),
                (4, 21, "Dia de Tiradentes"),
                (5, 1, "Dia do Trabalho"),
                (9, 7, "Independência do Brasil"),
                (10, 12, "Nossa Senhora Aparecida"),
                (11, 2, "Dia de Finados"),
                (11, 15, "Proclamação da República"),
                (11, 20, "Consciência Negra"),
                (12, 25, "Natal"),
            ] {
                add_event(
                    recurring_date(year, month, day),
                    name,
                    "Feriado nacional previsto na legislação federal.",
                    "national",
                    None,
                    None,
                    "brazil-recurring-law",
                );
            }
        }

        if preferences.include_state && preferences.state_code.as_deref() == Some("RJ") {
            add_event(
                recurring_date(year, 4, 23),
                "Dia de São Jorge",
                "Feriado estadual no Rio de Janeiro (Lei Estadual 5.198/2008).",
                "state",
                Some("RJ"),
                None,
                "rj-law-5198-2008",
            );
        }

        if preferences.include_municipal && preferences.city_code.as_deref() == Some("3302403") {
            let easter = easter_sunday(year);
            for (date, name, description) in [
                (
                    easter - Duration::days(2),
                    "Sexta-Feira Santa",
                    "Feriado religioso municipal em Macaé.",
                ),
                (
                    easter + Duration::days(60),
                    "Corpus Christi",
                    "Feriado religioso municipal em Macaé.",
                ),
                (
                    recurring_date(year, 6, 24),
                    "São João Batista",
                    "Feriado municipal do padroeiro de Macaé.",
                ),
                (
                    recurring_date(year, 7, 29),
                    "Aniversário de Macaé",
                    "Feriado municipal pelo aniversário da cidade.",
                ),
            ] {
                add_event(
                    date,
                    name,
                    description,
                    "municipal",
                    Some("RJ"),
                    Some("3302403"),
                    "macae-recurring-law",
                );
            }
        }
    }
    events
}

fn recurring_date(year: i32, month: u32, day: u32) -> NaiveDate {
    NaiveDate::from_ymd_opt(year, month, day).expect("recurring holiday date is valid")
}

fn easter_sunday(year: i32) -> NaiveDate {
    let a = year % 19;
    let b = year / 100;
    let c = year % 100;
    let d = b / 4;
    let e = b % 4;
    let f = (b + 8) / 25;
    let g = (b - f + 1) / 3;
    let h = (19 * a + b - d - g + 15) % 30;
    let i = c / 4;
    let k = c % 4;
    let l = (32 + 2 * e + 2 * i - h - k) % 7;
    let m = (a + 11 * h + 22 * l) / 451;
    let month = (h + l - 7 * m + 114) / 31;
    let day = (h + l - 7 * m + 114) % 31 + 1;
    recurring_date(year, month as u32, day as u32)
}

fn holiday_priority(kind: &str) -> u8 {
    match kind {
        "legal" => 3,
        "optional" => 2,
        "commemorative" => 1,
        _ => 0,
    }
}

fn is_generic_holiday_name(name: &str) -> bool {
    matches!(
        canonical_event_name(name).as_str(),
        "feriado" | "feriado municipal" | "facultativo" | "ponto facultativo"
    )
}

fn canonical_event_name(name: &str) -> String {
    let folded: String = name
        .chars()
        .flat_map(char::to_lowercase)
        .map(|character| match character {
            'á' | 'à' | 'â' | 'ã' => 'a',
            'é' | 'ê' => 'e',
            'í' => 'i',
            'ó' | 'ô' | 'õ' => 'o',
            'ú' | 'ü' => 'u',
            'ç' => 'c',
            character if character.is_alphanumeric() => character,
            _ => ' ',
        })
        .collect();
    let mut words: Vec<&str> = folded.split_whitespace().collect();
    if words.first() == Some(&"dia") {
        words.remove(0);
        if matches!(words.first(), Some(&"de" | &"da" | &"do" | &"das" | &"dos")) {
            words.remove(0);
        }
    }
    words.join(" ")
}

fn holidays_are_duplicates(left: &HolidayDto, right: &HolidayDto) -> bool {
    if left.date != right.date {
        return false;
    }
    let left_name = canonical_event_name(&left.name);
    let right_name = canonical_event_name(&right.name);
    (!left_name.is_empty() && left_name == right_name)
        || (left_name.contains("carnaval") && right_name.contains("carnaval"))
        || (left_name.contains("consciencia negra") && right_name.contains("consciencia negra"))
        || ((is_generic_holiday_name(&left.name) || is_generic_holiday_name(&right.name))
            && left.kind == "legal"
            && right.kind == "legal")
}

fn merge_duplicate_holiday(mut left: HolidayDto, mut right: HolidayDto) -> HolidayDto {
    if holiday_priority(&right.kind) > holiday_priority(&left.kind)
        || (holiday_priority(&right.kind) == holiday_priority(&left.kind)
            && is_generic_holiday_name(&left.name)
            && !is_generic_holiday_name(&right.name))
    {
        std::mem::swap(&mut left, &mut right);
    }
    if is_generic_holiday_name(&left.name) && !is_generic_holiday_name(&right.name) {
        left.name = right.name;
    }
    let right_description_is_better = right
        .description
        .as_ref()
        .is_some_and(|value| value.len() > left.description.as_deref().unwrap_or_default().len());
    if right_description_is_better {
        left.description = right.description;
    }
    left
}

fn deduplicate_holidays(mut holidays: Vec<HolidayDto>) -> Vec<HolidayDto> {
    holidays.sort_by_key(|holiday| {
        (
            holiday.date.clone(),
            Reverse(holiday_priority(&holiday.kind)),
            holiday.name.clone(),
        )
    });
    let mut deduplicated: Vec<HolidayDto> = Vec::with_capacity(holidays.len());
    for holiday in holidays {
        if let Some(index) = deduplicated
            .iter()
            .rposition(|candidate| holidays_are_duplicates(candidate, &holiday))
        {
            let previous = deduplicated.remove(index);
            deduplicated.insert(index, merge_duplicate_holiday(previous, holiday));
        } else {
            deduplicated.push(holiday);
        }
    }
    deduplicated.sort_by_key(|holiday| {
        (
            holiday.date.clone(),
            Reverse(holiday_priority(&holiday.kind)),
            holiday.name.clone(),
        )
    });
    deduplicated
}

fn coverage_is_complete(coverage: &[CoverageDto], from_year: i32, to_year: i32) -> bool {
    (from_year..=to_year).all(|year| {
        SOURCES.iter().all(|source| {
            coverage.iter().any(|item| {
                item.year == year && item.source == source.name && item.status == "ready"
            })
        })
    })
}

async fn ensure_year(state: &AppState, year: i32) {
    let [
        national,
        state_result,
        municipal,
        facultative,
        commemorative,
    ] = SOURCES;
    let ((), (), (), (), ()) = tokio::join!(
        ensure_source(state, national, year),
        ensure_source(state, state_result, year),
        ensure_source(state, municipal, year),
        ensure_source(state, facultative, year),
        ensure_source(state, commemorative, year),
    );
}

async fn ensure_source(state: &AppState, source: SourceDefinition, year: i32) {
    let fresh = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM holiday_source_snapshots WHERE source = $1 AND holiday_year = $2 \
         AND status = 'ready' AND fetched_at > now() - interval '7 days')",
    )
    .bind(source.name)
    .bind(year)
    .fetch_one(&state.pool)
    .await
    .unwrap_or(false);
    if fresh {
        return;
    }

    if let Err(error) = refresh_source(state, source, year).await {
        tracing::warn!(source = source.name, year, error = %error, "holiday source refresh failed");
        let unavailable = error.contains("returned 404");
        let _ = sqlx::query(
            "INSERT INTO holiday_source_snapshots(source, holiday_year, status, last_error) \
             VALUES($1, $2, $3, $4) ON CONFLICT(source, holiday_year) DO UPDATE SET \
             status = CASE WHEN holiday_source_snapshots.fetched_at IS NULL THEN excluded.status ELSE 'stale' END, \
             last_error = excluded.last_error",
        )
        .bind(source.name)
        .bind(year)
        .bind(if unavailable { "unavailable" } else { "error" })
        .bind(error)
        .execute(&state.pool)
        .await;
    }
}

async fn refresh_source(
    state: &AppState,
    source: SourceDefinition,
    year: i32,
) -> Result<(), String> {
    let url = format!("{FERIADOS_BRASIL_BASE_URL}/{}/{year}.json", source.path);
    let response = state
        .http
        .get(url)
        .send()
        .await
        .map_err(|error| format!("{} request failed: {error}", source.name))?;
    let status = response.status();
    if !status.is_success() {
        return Err(format!("{} returned {}", source.name, status.as_u16()));
    }
    let payload = response
        .text()
        .await
        .map_err(|error| format!("{} body failed: {error}", source.name))?;
    let entries = normalize_source_payload(source, year, &payload)?;
    if entries.is_empty() {
        return Err(format!("{} returned an empty snapshot", source.name));
    }

    let mut transaction = state
        .pool
        .begin()
        .await
        .map_err(|error| format!("{} transaction failed: {error}", source.name))?;
    sqlx::query("DELETE FROM holiday_entries WHERE source = $1 AND holiday_year = $2")
        .bind(source.name)
        .bind(year)
        .execute(&mut *transaction)
        .await
        .map_err(|error| format!("{} replacement delete failed: {error}", source.name))?;
    for entry in entries {
        sqlx::query(
            "INSERT INTO holiday_entries(source, source_key, holiday_date, holiday_year, name, description, \
             kind, scope_level, state_code, city_code) VALUES($1, $2, $3::date, $4, $5, $6, $7, $8, $9, $10)",
        )
        .bind(source.name)
        .bind(entry.source_key)
        .bind(entry.date)
        .bind(entry.year)
        .bind(entry.name)
        .bind(entry.description)
        .bind(entry.kind)
        .bind(entry.scope)
        .bind(entry.state_code)
        .bind(entry.city_code)
        .execute(&mut *transaction)
        .await
        .map_err(|error| format!("{} insert failed: {error}", source.name))?;
    }
    sqlx::query(
        "INSERT INTO holiday_source_snapshots(source, holiday_year, status, fetched_at, last_error) \
         VALUES($1, $2, 'ready', now(), NULL) ON CONFLICT(source, holiday_year) DO UPDATE SET \
         status = 'ready', fetched_at = now(), last_error = NULL",
    )
    .bind(source.name)
    .bind(year)
    .execute(&mut *transaction)
    .await
    .map_err(|error| format!("{} snapshot update failed: {error}", source.name))?;
    transaction
        .commit()
        .await
        .map_err(|error| format!("{} commit failed: {error}", source.name))?;
    Ok(())
}

fn normalize_source_payload(
    source: SourceDefinition,
    year: i32,
    payload: &str,
) -> Result<Vec<NormalizedHoliday>, String> {
    let raw_entries: Vec<RawHoliday> = serde_json::from_str(payload)
        .map_err(|error| format!("{} JSON is invalid: {error}", source.name))?;
    let mut normalized = BTreeMap::new();
    for raw in raw_entries {
        if raw.tipo != source.expected_type {
            tracing::warn!(
                source = source.name,
                expected_type = source.expected_type,
                received_type = raw.tipo,
                "ignoring holiday entry from the wrong source category"
            );
            continue;
        }
        let date = NaiveDate::parse_from_str(&raw.data, "%d/%m/%Y")
            .map_err(|_| format!("{} contains invalid date {}", source.name, raw.data))?;
        if date.year() != year {
            return Err(format!(
                "{} expected year {year} but received {}",
                source.name, raw.data
            ));
        }
        let name = raw.nome.trim().to_owned();
        if name.is_empty() {
            return Err(format!("{} contains an empty holiday name", source.name));
        }
        let (scope, state_code, city_code) = normalize_source_location(&raw, source)?;
        let date_text = date.format("%Y-%m-%d").to_string();
        let source_key = raw
            .id
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| {
                format!(
                    "{}|{}|{}|{}|{}|{}",
                    date_text,
                    source.kind,
                    scope,
                    state_code.as_deref().unwrap_or(""),
                    city_code.as_deref().unwrap_or(""),
                    name.to_lowercase()
                )
            });
        normalized.insert(
            source_key.clone(),
            NormalizedHoliday {
                source_key,
                date: date_text,
                year,
                name,
                description: raw.descricao.and_then(|value| {
                    let trimmed = value.trim().to_owned();
                    (!trimmed.is_empty()).then_some(trimmed)
                }),
                kind: source.kind,
                scope,
                state_code,
                city_code,
            },
        );
    }
    Ok(normalized.into_values().collect())
}
fn normalize_source_location(
    raw: &RawHoliday,
    source: SourceDefinition,
) -> Result<(&'static str, Option<String>, Option<String>), String> {
    if source.scope == "national" {
        return Ok(("national", None, None));
    }
    let state_code = raw
        .uf
        .as_deref()
        .filter(|value| !value.trim().is_empty())
        .map(|value| normalize_source_state(Some(value), source.name))
        .transpose()?
        .flatten();
    let city_code = raw.codigo_ibge.map(|value| value.to_string());
    if source.scope == "dynamic" {
        return match (state_code, city_code) {
            (Some(state), Some(city)) => Ok(("municipal", Some(state), Some(city))),
            (Some(state), None) => Ok(("state", Some(state), None)),
            (None, None) => Ok(("national", None, None)),
            (None, Some(_)) => Err(format!("{} municipal entry lacks uf", source.name)),
        };
    }
    if source.scope == "state" {
        return Ok((
            "state",
            Some(state_code.ok_or_else(|| format!("{} regional entry lacks uf", source.name))?),
            None,
        ));
    }
    Ok((
        "municipal",
        Some(state_code.ok_or_else(|| format!("{} regional entry lacks uf", source.name))?),
        Some(
            city_code
                .ok_or_else(|| format!("{} municipal entry lacks codigo_ibge", source.name))?,
        ),
    ))
}

fn normalize_source_state(value: Option<&str>, source: &str) -> Result<Option<String>, String> {
    let value = value.ok_or_else(|| format!("{source} regional entry lacks uf"))?;
    let normalized = value.trim().to_ascii_uppercase();
    if !VALID_STATE_CODES.contains(&normalized.as_str()) {
        return Err(format!("{source} contains invalid state code {normalized}"));
    }
    Ok(Some(normalized))
}

async fn ensure_municipalities(state: &AppState, state_code: &str) -> Result<(), ApiError> {
    let cached = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM brazil_municipalities WHERE state_code = $1 \
         AND fetched_at > now() - interval '30 days')",
    )
    .bind(state_code)
    .fetch_one(&state.pool)
    .await
    .map_err(ApiError::database)?;
    if cached {
        return Ok(());
    }

    let url = format!(
        "https://servicodados.ibge.gov.br/api/v1/localidades/estados/{state_code}/municipios"
    );
    let response = state.http.get(url).send().await.map_err(|error| {
        ApiError::external(format!("IBGE municipality request failed: {error}"))
    })?;
    if !response.status().is_success() {
        return cached_municipality_fallback(
            state,
            state_code,
            format!(
                "IBGE municipality request returned {}",
                response.status().as_u16()
            ),
        )
        .await;
    }
    let municipalities: Vec<IbgeMunicipality> = response.json().await.map_err(|error| {
        ApiError::external(format!("IBGE municipality response is invalid: {error}"))
    })?;
    if municipalities.is_empty() {
        return cached_municipality_fallback(
            state,
            state_code,
            "IBGE municipality response was empty".to_owned(),
        )
        .await;
    }

    let mut transaction = state.pool.begin().await.map_err(ApiError::database)?;
    sqlx::query("DELETE FROM brazil_municipalities WHERE state_code = $1")
        .bind(state_code)
        .execute(&mut *transaction)
        .await
        .map_err(ApiError::database)?;
    for municipality in municipalities {
        let name = municipality.nome.trim();
        if name.is_empty() {
            return Err(ApiError::external(
                "IBGE municipality response contains an empty name",
            ));
        }
        sqlx::query(
            "INSERT INTO brazil_municipalities(city_code, state_code, name) VALUES($1, $2, $3)",
        )
        .bind(municipality.id.to_string())
        .bind(state_code)
        .bind(name)
        .execute(&mut *transaction)
        .await
        .map_err(ApiError::database)?;
    }
    transaction.commit().await.map_err(ApiError::database)?;
    Ok(())
}

async fn cached_municipality_fallback(
    state: &AppState,
    state_code: &str,
    error: String,
) -> Result<(), ApiError> {
    let has_cache = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM brazil_municipalities WHERE state_code = $1)",
    )
    .bind(state_code)
    .fetch_one(&state.pool)
    .await
    .map_err(ApiError::database)?;
    if has_cache {
        tracing::warn!(state = state_code, error, "using stale municipality cache");
        Ok(())
    } else {
        Err(ApiError::external(error))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_state_and_municipal_entries_without_losing_same_day_events() {
        let source = SOURCES[2];
        let payload = r#"[
          {"data":"25/01/2026","nome":"Aniversário de São Paulo","tipo":"MUNICIPAL","uf":"SP","codigo_ibge":3550308},
          {"data":"25/01/2026","nome":"Outro evento legal","tipo":"MUNICIPAL","uf":"SP","codigo_ibge":3550308}
        ]"#;
        let entries = normalize_source_payload(source, 2026, payload).expect("valid payload");
        assert_eq!(entries.len(), 2);
        assert!(entries.iter().all(|entry| entry.scope == "municipal"));
        assert!(
            entries
                .iter()
                .all(|entry| entry.state_code.as_deref() == Some("SP"))
        );
        assert!(
            entries
                .iter()
                .all(|entry| entry.city_code.as_deref() == Some("3550308"))
        );
    }
    #[test]
    fn ignores_mislabeled_entries_without_rejecting_the_source() {
        let payload = r#"[
          {"data":"24/06/2026","nome":"São João","tipo":"MUNICIPAL","uf":"RJ","codigo_ibge":3302403},
          {"data":"19/03/2026","nome":"São José","tipo":"ESTADUAL","uf":"CE","codigo_ibge":2303709},
          {"data":"29/07/2026","nome":"Aniversário de Macaé","tipo":"MUNICIPAL","uf":"RJ","codigo_ibge":3302403}
        ]"#;
        let entries = normalize_source_payload(SOURCES[2], 2026, payload).expect("usable payload");
        assert_eq!(entries.len(), 2);
        assert!(
            entries
                .iter()
                .all(|entry| entry.city_code.as_deref() == Some("3302403"))
        );
    }

    #[test]
    fn infers_facultative_scope_from_location_fields() {
        let payload = r#"[
          {"data":"16/02/2026","nome":"Carnaval","tipo":"FACULTATIVO","uf":"","codigo_ibge":null},
          {"data":"19/03/2026","nome":"São José","tipo":"FACULTATIVO","uf":"CE","codigo_ibge":null},
          {"data":"29/03/2026","nome":"Aniversário da Cidade","tipo":"FACULTATIVO","uf":"PR","codigo_ibge":4106902}
        ]"#;
        let entries = normalize_source_payload(SOURCES[3], 2026, payload).expect("valid payload");
        assert_eq!(
            entries.iter().map(|entry| entry.scope).collect::<Vec<_>>(),
            vec!["national", "state", "municipal"]
        );
    }

    #[test]
    fn deduplicates_with_legal_priority_and_keeps_unrelated_events() {
        let event = |name: &str, kind: &str| HolidayDto {
            date: "2026-11-20".to_owned(),
            name: name.to_owned(),
            description: None,
            kind: kind.to_owned(),
            scope: "national".to_owned(),
            state_code: None,
            city_code: None,
            source: kind.to_owned(),
        };
        let events = deduplicate_holidays(vec![
            event("Consciência Negra", "legal"),
            event("Dia da Consciência Negra", "commemorative"),
            event("Dia Nacional de Zumbi e da Consciência Negra", "optional"),
            event("Dia do Biomédico", "commemorative"),
        ]);
        assert_eq!(events.len(), 2);
        assert!(events.iter().any(|holiday| holiday.kind == "legal"));
        assert!(
            events
                .iter()
                .any(|holiday| holiday.name == "Dia do Biomédico")
        );
    }

    #[test]
    fn generates_recurring_macae_legal_holidays_for_multiple_years() {
        let preferences = HolidayPreferences {
            state_code: Some("RJ".to_owned()),
            city_code: Some("3302403".to_owned()),
            include_national: true,
            include_state: true,
            include_municipal: true,
            include_commemorative: true,
            include_optional: true,
            revision: 1,
            updated_at: "2026-01-01T00:00:00.000Z".to_owned(),
        };
        let events = recurring_legal_events(
            &preferences,
            recurring_date(2026, 1, 1),
            recurring_date(2027, 12, 31),
        );

        assert_eq!(events.len(), 28);
        assert!(events.iter().any(|holiday| {
            holiday.date == "2026-06-04"
                && holiday.name == "Corpus Christi"
                && holiday.kind == "legal"
        }));
        assert!(events.iter().any(|holiday| {
            holiday.date == "2027-05-27"
                && holiday.name == "Corpus Christi"
                && holiday.kind == "legal"
        }));
        assert!(events.iter().any(|holiday| {
            holiday.date == "2027-07-29"
                && holiday.name == "Aniversário de Macaé"
                && holiday.source == "macae-recurring-law"
        }));
    }

    #[test]
    fn marks_year_complete_only_when_every_source_is_ready() {
        let mut coverage: Vec<CoverageDto> = SOURCES
            .iter()
            .map(|source| CoverageDto {
                source: source.name.to_owned(),
                year: 2026,
                status: "ready".to_owned(),
                fetched_at: None,
                last_error: None,
            })
            .collect();

        assert!(coverage_is_complete(&coverage, 2026, 2026));
        coverage[0].status = "error".to_owned();
        assert!(!coverage_is_complete(&coverage, 2026, 2026));
        assert!(!coverage_is_complete(&coverage, 2026, 2027));
    }

    #[test]
    fn rejects_snapshot_for_the_wrong_year() {
        let payload = r#"[{"data":"01/01/2025","nome":"Ano Novo","tipo":"NACIONAL"}]"#;
        assert!(normalize_source_payload(SOURCES[0], 2026, payload).is_err());
    }

    #[test]
    fn normalizes_preference_location_and_clears_empty_values() {
        let input = HolidayPreferencesInput {
            state_code: Some(" sp ".to_owned()),
            city_code: Some("  ".to_owned()),
            include_national: true,
            include_state: true,
            include_municipal: true,
            include_commemorative: true,
            include_optional: true,
        };
        let normalized = normalize_preferences(input).expect("valid preferences");
        assert_eq!(normalized.state_code.as_deref(), Some("SP"));
        assert_eq!(normalized.city_code, None);
    }

    #[test]
    fn rejects_city_without_state() {
        let input = HolidayPreferencesInput {
            state_code: None,
            city_code: Some("3550308".to_owned()),
            include_national: true,
            include_state: true,
            include_municipal: true,
            include_commemorative: true,
            include_optional: true,
        };
        assert!(normalize_preferences(input).is_err());
    }

    #[test]
    fn validates_bounded_floating_date_ranges() {
        let valid = HolidayRangeQuery {
            from: "2026-08-31".to_owned(),
            to: "2026-10-11".to_owned(),
        };
        assert!(validate_range(&valid).is_ok());
        let timestamp = HolidayRangeQuery {
            from: "2026-08-31T00:00:00Z".to_owned(),
            to: "2026-10-11".to_owned(),
        };
        assert!(validate_range(&timestamp).is_err());
    }
}
