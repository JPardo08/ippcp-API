#!/usr/bin/env bash
# phase1_provider_publish.sh — Fase 1: publicación provider (test3).
#
# Requisitos: Bash 4.3+, curl, jq (ver scripts/scripts_README.md).
#
# Prerrequisito: phase0 OK (phase0_env.sh o SUFFIX exportado).
# Continuar ejecución: source runtime/env/latest/phase0_env.sh  (o phase1_env.sh si re-ejecutas)
#
# Uso:
#   /opt/homebrew/bin/bash scripts/phase1_provider_publish.sh

set -euo pipefail
[[ $- != *x* ]] || set +x

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_common.sh
source "${_SCRIPT_DIR}/lib_common.sh"

readonly REQUEST_LIST_BODY='{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"offset":0,"limit":50,"filterExpression":[]}'
readonly VOCAB_LIST_BODY='{}'
readonly PHASE1_PROVIDER_ID_HEADER_KEY='header:X-Provider-Id'
readonly PHASE1_API_KEY_HEADER_KEY='header:X-Api-Key'

PHASE1_STEP="init"
PHASE1_SENSITIVE_TMP_DIR=""

_phase1_cleanup() {
  if [[ -n "${PHASE1_SENSITIVE_TMP_DIR}" && -d "${PHASE1_SENSITIVE_TMP_DIR}" ]]; then
    rm -rf "${PHASE1_SENSITIVE_TMP_DIR}"
    PHASE1_SENSITIVE_TMP_DIR=""
  fi
}

_phase1_on_err() {
  local rc=$?
  _phase1_cleanup
  if [[ -n "${RUN_DIR:-}" && -d "${RUN_DIR}" ]]; then
    lib_write_summary 1 "${PHASE1_STEP}" fail "{\"exit_code\":${rc}}" 2>/dev/null || true
    lib_set_phase_status 1 fail 2>/dev/null || true
  fi
  exit "${rc}"
}
trap _phase1_on_err ERR
trap _phase1_cleanup EXIT

_phase1_write_json() {
  local dest="$1"
  local tmp="${dest}.$$"
  cat > "${tmp}"
  mv "${tmp}" "${dest}"
}

_phase1_ensure_sensitive_tmp_dir() {
  if [[ -z "${PHASE1_SENSITIVE_TMP_DIR}" || ! -d "${PHASE1_SENSITIVE_TMP_DIR}" ]]; then
    PHASE1_SENSITIVE_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/phase1-sensitive.XXXXXX")"
    chmod 700 "${PHASE1_SENSITIVE_TMP_DIR}"
  fi
}

_phase1_redact_json_file() {
  local source_file="$1"
  local dest_file="$2"
  local tmp="${dest_file}.$$"

  jq '
    def redact:
      if type == "object" then
        with_entries(
          if (.key | ascii_downcase | endswith("header:x-api-key")) then
            .value = "<redacted>"
          elif (.value | type) == "object" or (.value | type) == "array" then
            .value |= redact
          else
            .
          end
        )
      elif type == "array" then map(redact)
      else .
      end;
    redact
  ' "${source_file}" > "${tmp}"
  mv "${tmp}" "${dest_file}"
}

_phase1_assert_no_sensitive_artifact() {
  local file="$1"
  [[ -f "${file}" ]] || return 0

  if awk '/Authorization|Bearer |access_token|INGESTA_API_BEARER_TOKEN|client_secret/ { found = 1; exit } END { exit found ? 0 : 1 }' "${file}"; then
    lib_die "Artefacto phase1 contiene material sensible o header Authorization: ${file}"
  fi

  if [[ -n "${INGESTA_API_KEY:-}" ]] \
    && printf '%s\n' "${INGESTA_API_KEY}" | grep -Fq -f - "${file}"; then
    lib_die "Artefacto phase1 contiene INGESTA_API_KEY sin redactar: ${file}"
  fi

  if [[ "${file}" == *.json ]] && jq -e '
    . as $root
    | any(paths(scalars) as $p;
        (($p[-1] | tostring | ascii_downcase | endswith("header:x-api-key")))
        and (($root | getpath($p)) != "<redacted>"))
  ' "${file}" >/dev/null 2>&1; then
    lib_die "Artefacto phase1 contiene header:X-Api-Key sin <redacted>: ${file}"
  fi
}

_phase1_curl_json_redacted() {
  local artifact_base="$1"
  shift

  _phase1_ensure_sensitive_tmp_dir
  local raw_base="${PHASE1_SENSITIVE_TMP_DIR}/$(basename "${artifact_base}")"
  local rc=0

  if lib_curl_json "${raw_base}" "$@"; then
    rc=0
  else
    rc=$?
  fi

  if [[ -f "${raw_base}.http" ]]; then
    cp "${raw_base}.http" "${artifact_base}.http"
  fi

  if [[ -s "${raw_base}.json" ]] && jq empty "${raw_base}.json" >/dev/null 2>&1; then
    _phase1_redact_json_file "${raw_base}.json" "${artifact_base}.json"
  else
    jq -n '{error: "non_json_response_redacted"}' > "${artifact_base}.json"
  fi

  _phase1_assert_no_sensitive_artifact "${artifact_base}.json"
  return "${rc}"
}

_phase1_list_and_summary() {
  local base="$1"
  local endpoint_key="$2"
  local step_id="$3"
  local body="${4:-${REQUEST_LIST_BODY}}"

  PHASE1_STEP="${step_id}"
  if [[ "${endpoint_key}" == "asset" ]]; then
    _phase1_curl_json_redacted "${PHASE1_DIR}/${base}" \
      -X POST "${PROVIDER_BASE}${ENDPOINTS[${endpoint_key}]}" \
      -H "Authorization: Bearer ${PROVIDER_JWT}" \
      -H "Content-Type: application/json" \
      -d "${body}"
  else
    lib_curl_json "${PHASE1_DIR}/${base}" \
      -X POST "${PROVIDER_BASE}${ENDPOINTS[${endpoint_key}]}" \
      -H "Authorization: Bearer ${PROVIDER_JWT}" \
      -H "Content-Type: application/json" \
      -d "${body}"
  fi

  local http count
  http="$(tr -d '\n' < "${PHASE1_DIR}/${base}.http")"
  count="$(jq 'length' "${PHASE1_DIR}/${base}.json")"
  lib_write_summary 1 "${step_id}" ok \
    "{\"http\":${http},\"count\":${count},\"artifact\":\"phase1/${base}\"}"
}

_phase1_create_and_summary() {
  local base="$1"
  local step_id="$2"
  local request_file="$3"
  local extra_meta_json="${4-}"
  shift 4

  if [[ -z "${extra_meta_json}" ]]; then
    extra_meta_json='{}'
  fi

  if [[ "${PHASE1_DEBUG:-0}" == "1" ]]; then
    lib_log INFO "_phase1_create_and_summary ${step_id}: extra_meta_json=${extra_meta_json}"
  fi

  if ! jq -e . >/dev/null 2>&1 <<< "${extra_meta_json}"; then
    lib_log ERROR "_phase1_create_and_summary: extra_meta_json inválido para ${step_id}: ${extra_meta_json}"
    lib_die "_phase1_create_and_summary: extra_meta_json inválido para ${step_id}"
  fi

  PHASE1_STEP="${step_id}"
  local http base_meta summary_meta

  local curl_ok=0
  if [[ "${step_id}" == "create_asset" ]]; then
    if _phase1_curl_json_redacted "${PHASE1_DIR}/${base}" \
      -H "Authorization: Bearer ${PROVIDER_JWT}" \
      -H "Content-Type: application/json" \
      -d "@${request_file}" \
      "$@"; then
      curl_ok=1
    fi
  elif lib_curl_json "${PHASE1_DIR}/${base}" \
    -H "Authorization: Bearer ${PROVIDER_JWT}" \
    -H "Content-Type: application/json" \
    -d "@${request_file}" \
    "$@"; then
    curl_ok=1
  fi

  if (( curl_ok == 0 )); then
    http="$(tr -d '\n\r' < "${PHASE1_DIR}/${base}.http")"
    if [[ "${http}" == "409" ]]; then
      lib_die "HTTP 409: recurso ya existe (SUFFIX=${SUFFIX}, paso=${step_id}). Inicia una ejecución nueva o diseña cleanup."
    fi
    return 1
  fi

  http="$(tr -d '\n\r' < "${PHASE1_DIR}/${base}.http")"
  [[ "${http}" =~ ^[0-9]+$ ]] \
    || lib_die "HTTP inválido para ${step_id}: ${http}"

  base_meta="$(
    jq -nc \
      --argjson http "${http}" \
      --arg artifact "phase1/${base}" \
      --arg request "phase1/$(basename "${request_file}")" \
      '{http: $http, artifact: $artifact, request: $request}'
  )"

  if [[ -z "${base_meta}" ]] || ! jq -e . >/dev/null 2>&1 <<< "${base_meta}"; then
    lib_die "_phase1_create_and_summary: base_meta inválido para ${step_id}"
  fi

  summary_meta="$(
    jq -nc \
      --argjson base "${base_meta}" \
      --argjson extra "${extra_meta_json}" \
      '$base + $extra'
  )"

  if [[ -z "${summary_meta}" ]] || ! jq -e . >/dev/null 2>&1 <<< "${summary_meta}"; then
    lib_die "_phase1_create_and_summary: summary_meta inválido para ${step_id}"
  fi

  lib_write_summary 1 "${step_id}" ok "${summary_meta}"
}

_phase1_extract_catalog_dataset() {
  local catalog_file="$1"
  local output_file="$2"
  local tmp="${output_file}.$$"

  jq -e --arg id "${ASSET_ID}" '
    (."dcat:dataset" // ."http://www.w3.org/ns/dcat#dataset")
    | (if type == "array" then . else [.] end)
    | map(select(."@id" == $id))
    | .[0] // empty
  ' "${catalog_file}" > "${tmp}"

  if [[ ! -s "${tmp}" ]] || ! jq -e . "${tmp}" >/dev/null 2>&1; then
    rm -f "${tmp}"
    lib_die "ASSET_ID ${ASSET_ID} no aparece en catálogo local del provider"
  fi

  mv "${tmp}" "${output_file}"
}

_phase1_extract_offer_policy() {
  local dataset_file="$1"
  local output_file="$2"
  local tmp="${output_file}.$$"

  jq -e '
    (
      .hasPolicy
      // ."odrl:hasPolicy"
      // ."http://www.w3.org/ns/odrl/2/hasPolicy"
    )
    | (if type == "array" then .[0] else . end)
  ' "${dataset_file}" > "${tmp}"

  if [[ ! -s "${tmp}" ]] || ! jq -e . "${tmp}" >/dev/null 2>&1; then
    rm -f "${tmp}"
    lib_die "No se pudo extraer hasPolicy del dataset seleccionado"
  fi

  mv "${tmp}" "${output_file}"
}

_phase1_validate_offer_policy() {
  local offer_file="$1"

  jq -e '
    def action_value:
      . as $a
      | if $a == null then ""
        elif ($a | type) == "object" then
          ($a."@id" // $a.id // $a.type // $a."@value" // ($a | tostring))
        else ($a | tostring)
        end;

    def last_fragment_is_use:
      . as $s
      | ($s | ascii_downcase | split("#") | last | split("/") | last | split(":") | last) == "use";

    def is_use_action:
      action_value | last_fragment_is_use;

    def policy_permissions:
      (.permission // ."odrl:permission" // ."http://www.w3.org/ns/odrl/2/permission" // [])
      | if type == "array" then . else [.] end;

    def policy_obligations:
      (.obligation // ."odrl:obligation" // ."http://www.w3.org/ns/odrl/2/obligation" // [])
      | if type == "array" then . else [.] end;

    def policy_prohibitions:
      (.prohibition // ."odrl:prohibition" // ."http://www.w3.org/ns/odrl/2/prohibition" // [])
      | if type == "array" then . else [.] end;

    def collection_len:
      if type == "array" then length else (if . == null then 0 else 1 end) end;

    def permission_action($perm):
      ($perm.action // $perm."odrl:action" // $perm."http://www.w3.org/ns/odrl/2/action" // null);

    (policy_permissions
      | any(permission_action(.) | is_use_action))
    and ((policy_obligations | collection_len) == 0)
    and ((policy_prohibitions | collection_len) == 0)
  ' "${offer_file}" >/dev/null \
    || lib_die "Offer policy inválida en ${offer_file}: requiere permission/action USE, obligation [] y prohibition []"
}

_phase1_sanitize_slug() {
  local slug="$1"
  printf '%s' "${slug}" | sed 's/[^A-Za-z0-9._-]/_/g'
}

_phase1_jq_string() {
  local config_file="$1"
  local field="$2"
  local value
  value="$(jq -r --arg f "${field}" '.[$f] // empty | select(type == "string" and length > 0)' "${config_file}")"
  [[ -n "${value}" ]] || lib_die "ASSET_CONFIG: campo obligatorio '${field}' vacío o ausente"
  printf '%s' "${value}"
}

_phase1_jq_array_json() {
  local config_file="$1"
  local field="${2:-keywords}"
  local value

  if ! value="$(
    jq -ce --arg field "${field}" '
      (.[$field] // [])
      | if type != "array" then
          error($field + " debe ser un array")
        else
          .
        end
      | if all(.[]; type == "string") then
          .
        else
          error($field + " debe ser un array de strings")
        end
    ' "${config_file}"
  )"; then
    lib_die "Campo ${field} inválido en ${config_file}: debe ser array de strings"
  fi

  [[ -n "${value}" ]] || value='[]'
  printf '%s' "${value}"
}

_phase1_validate_keywords_json() {
  if [[ -z "${ASSET_KEYWORDS_JSON:-}" ]]; then
    ASSET_KEYWORDS_JSON='[]'
  fi

  if ! jq -e . >/dev/null 2>&1 <<< "${ASSET_KEYWORDS_JSON}"; then
    lib_die "ASSET_KEYWORDS_JSON no es JSON válido: ${ASSET_KEYWORDS_JSON}"
  fi

  if ! jq -e 'type == "array" and all(.[]; type == "string")' >/dev/null 2>&1 <<< "${ASSET_KEYWORDS_JSON}"; then
    lib_die "ASSET_KEYWORDS_JSON debe ser un array JSON de strings"
  fi

  export ASSET_KEYWORDS_JSON
}

_phase1_validate_asset_id() {
  local asset_id="$1"
  [[ "${asset_id}" =~ ^[A-Za-z0-9._-]+$ ]] \
    || lib_die "asset_id contiene caracteres no permitidos: ${asset_id}"
}

_phase1_extension_allowed() {
  case "${1}" in
    json|xml|gml|csv|txt|ttl|rdf|xlsx|zip) return 0 ;;
    *) return 1 ;;
  esac
}

_phase1_validate_content_kind_value() {
  case "${1}" in
    json|text|binary) return 0 ;;
    *)
      lib_die "ASSET_CONFIG: content_kind debe ser json, text o binary (recibido: ${1})"
      ;;
  esac
}

_phase1_validate_extension_value() {
  local extension="$1"
  _phase1_extension_allowed "${extension}" \
    || lib_die "ASSET_CONFIG: extension no permitida (recibido: ${extension}). Permitidas: json, xml, gml, csv, txt, ttl, rdf, xlsx, zip"
}

_phase1_validate_kind_extension_pair() {
  local content_kind="$1"
  local extension="$2"

  case "${content_kind}" in
    json)
      [[ "${extension}" == "json" ]] \
        || lib_die "ASSET_CONFIG: content_kind=json requiere extension=json (recibido: ${extension})"
      ;;
    text)
      case "${extension}" in
        xml|gml|csv|txt|ttl|rdf) return 0 ;;
        *)
          lib_die "ASSET_CONFIG: content_kind=text requiere extension xml,gml,csv,txt,ttl o rdf (recibido: ${extension})"
          ;;
      esac
      ;;
    binary)
      case "${extension}" in
        xlsx|zip) return 0 ;;
        *)
          lib_die "ASSET_CONFIG: content_kind=binary requiere extension xlsx o zip (recibido: ${extension})"
          ;;
      esac
      ;;
  esac
}

_phase1_default_media_type() {
  case "${1}" in
    json) printf '%s' 'application/json' ;;
    csv) printf '%s' 'text/csv' ;;
    txt) printf '%s' 'text/plain' ;;
    xml) printf '%s' 'application/xml' ;;
    gml) printf '%s' 'application/gml+xml' ;;
    xlsx) printf '%s' 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ;;
    zip) printf '%s' 'application/zip' ;;
    ttl) printf '%s' 'text/turtle' ;;
    rdf) printf '%s' 'application/rdf+xml' ;;
    *) lib_die "ASSET_CONFIG: no hay media_type por defecto para extension=${1}" ;;
  esac
}

_phase1_reject_b2_config() {
  local config_file="$1"
  local storage_mode asset_type

  storage_mode="$(jq -r '.storage_mode // empty | select(type == "string")' "${config_file}")"
  asset_type="$(jq -r '.type // empty | select(type == "string")' "${config_file}")"

  if [[ "${storage_mode}" == "inesdatastore" || "${asset_type}" == "InesDataStore" ]]; then
    lib_die "Esta config es de Fase B2/InesDataStore. Usa scripts/phase1b_provider_upload_file.sh con ASSET_UPLOAD_CONFIG=${ASSET_CONFIG:-<config>}"
  fi
}

_phase1_validate_asset_config() {
  local config_file="$1"

  jq empty "${config_file}" \
    || lib_die "ASSET_CONFIG no es JSON válido: ${config_file}"

  jq -e '(.keywords // []) | type == "array" and all(.[]; type == "string")' "${config_file}" >/dev/null \
    || lib_die "ASSET_CONFIG: keywords debe ser un array de strings"
  jq -e '(.requires_provider_id_header // false) | type == "boolean"' "${config_file}" >/dev/null \
    || lib_die "ASSET_CONFIG: requires_provider_id_header debe ser booleano"
  jq -e '(.requires_api_key_header // false) | type == "boolean"' "${config_file}" >/dev/null \
    || lib_die "ASSET_CONFIG: requires_api_key_header debe ser booleano"

  local asset_type content_kind extension base_url
  asset_type="$(_phase1_jq_string "${config_file}" type)"
  content_kind="$(_phase1_jq_string "${config_file}" content_kind)"
  extension="$(_phase1_jq_string "${config_file}" extension)"
  base_url="$(_phase1_jq_string "${config_file}" base_url)"

  [[ "${asset_type}" == "HttpData" ]] \
    || lib_die "ASSET_CONFIG: type debe ser HttpData (recibido: ${asset_type})"
  _phase1_validate_content_kind_value "${content_kind}"
  _phase1_validate_extension_value "${extension}"
  _phase1_validate_kind_extension_pair "${content_kind}" "${extension}"
  [[ "${base_url}" =~ ^https?:// ]] \
    || lib_die "ASSET_CONFIG: base_url debe empezar por http:// o https://"
}

_phase1_set_legacy_asset_defaults() {
  export ASSET_ID_CUSTOM=0
  export ASSET_NAME="Asset taller ${SUFFIX}"
  export ASSET_DESCRIPTION="Dataset de prueba para flujo end-to-end"
  export ASSET_BASE_URL="https://jsonplaceholder.typicode.com/todos"
  export ASSET_DATA_ADDRESS_NAME="todos"
  export ASSET_CONTENT_KIND="json"
  export ASSET_EXTENSION="json"
  export ASSET_MEDIA_TYPE="application/json"
  export STORAGE_MODE="httpdata"
  ASSET_KEYWORDS_JSON='["taller","demo","dataspace"]'
  export ASSET_KEYWORDS_JSON
  ASSET_REQUIRES_PROVIDER_ID_HEADER=0
  ASSET_REQUIRES_API_KEY_HEADER=0
  unset ASSET_CONFIG ASSET_SLUG
}

_phase1_validate_provider_id_header_env() {
  [[ -n "${INGESTA_API_PROVIDER_ID:-}" ]] \
    || lib_die "INGESTA_API_PROVIDER_ID requerido porque ASSET_CONFIG declara requires_provider_id_header=true"
  [[ "${INGESTA_API_PROVIDER_ID}" =~ ^[0-9]+$ ]] \
    || lib_die "INGESTA_API_PROVIDER_ID debe ser numérico; no usar UUID de Keycloak."
}

_phase1_validate_api_key_header_env() {
  [[ -n "${INGESTA_API_KEY:-}" ]] \
    || lib_die "INGESTA_API_KEY requerida porque ASSET_CONFIG declara requires_api_key_header=true"
}

_phase1_load_asset_config() {
  if [[ -z "${ASSET_CONFIG:-}" ]]; then
    _phase1_set_legacy_asset_defaults
    _phase1_validate_keywords_json
    return 0
  fi

  local config_path="${ASSET_CONFIG}"
  if [[ "${config_path}" != /* ]]; then
    config_path="${API_ROOT}/${config_path}"
  fi

  [[ -f "${config_path}" ]] \
    || lib_die "ASSET_CONFIG no encontrado: ${config_path}"

  _phase1_reject_b2_config "${config_path}"

  _phase1_validate_asset_config "${config_path}"

  local raw_slug safe_slug config_asset_id media_type content_kind extension
  local requires_provider_id_header requires_api_key_header
  raw_slug="$(_phase1_jq_string "${config_path}" asset_slug)"
  safe_slug="$(_phase1_sanitize_slug "${raw_slug}")"
  [[ -n "${safe_slug}" ]] || lib_die "ASSET_CONFIG: asset_slug inválido tras sanitizar"

  content_kind="$(_phase1_jq_string "${config_path}" content_kind)"
  extension="$(_phase1_jq_string "${config_path}" extension)"

  config_asset_id="$(jq -r '.asset_id // empty | select(type == "string" and length > 0)' "${config_path}")"
  if [[ -n "${config_asset_id}" ]]; then
    _phase1_validate_asset_id "${config_asset_id}"
    export ASSET_ID="${config_asset_id}"
  else
    export ASSET_ID="${safe_slug}-${SUFFIX}"
  fi

  media_type="$(jq -r '.media_type // empty | select(type == "string" and length > 0)' "${config_path}")"
  if [[ -z "${media_type}" ]]; then
    media_type="$(_phase1_default_media_type "${extension}")"
  fi

  requires_provider_id_header="$(jq -r '.requires_provider_id_header // false' "${config_path}")"
  if [[ "${requires_provider_id_header}" == "true" ]]; then
    _phase1_validate_provider_id_header_env
    ASSET_REQUIRES_PROVIDER_ID_HEADER=1
  else
    ASSET_REQUIRES_PROVIDER_ID_HEADER=0
  fi

  requires_api_key_header="$(jq -r '.requires_api_key_header // false' "${config_path}")"
  if [[ "${requires_api_key_header}" == "true" ]]; then
    _phase1_validate_api_key_header_env
    ASSET_REQUIRES_API_KEY_HEADER=1
  else
    ASSET_REQUIRES_API_KEY_HEADER=0
  fi

  export ASSET_ID_CUSTOM=1
  export ASSET_CONFIG="${ASSET_CONFIG}"
  export ASSET_SLUG="${safe_slug}"
  export ASSET_NAME="$(_phase1_jq_string "${config_path}" name)"
  export ASSET_DESCRIPTION="$(_phase1_jq_string "${config_path}" description)"
  export ASSET_BASE_URL="$(_phase1_jq_string "${config_path}" base_url)"
  export ASSET_CONTENT_KIND="${content_kind}"
  export ASSET_EXTENSION="${extension}"
  export ASSET_MEDIA_TYPE="${media_type}"
  export STORAGE_MODE="httpdata"
  export ASSET_KEYWORDS_JSON="$(_phase1_jq_array_json "${config_path}" keywords)"
  export ASSET_DATA_ADDRESS_NAME="${safe_slug}"
  _phase1_validate_keywords_json
}

_phase1_write_asset_request() {
  local dest="$1"
  local tmp="${dest}.$$"

  _phase1_validate_keywords_json

  lib_log INFO "Asset config: ${ASSET_CONFIG:-<legacy>}"
  lib_log INFO "ASSET_ID=${ASSET_ID}"
  lib_log INFO "ASSET_BASE_URL=${ASSET_BASE_URL}"
  lib_log INFO "ASSET_CONTENT_KIND=${ASSET_CONTENT_KIND}"
  lib_log INFO "ASSET_EXTENSION=${ASSET_EXTENSION}"
  lib_log INFO "ASSET_KEYWORDS_JSON=${ASSET_KEYWORDS_JSON}"
  lib_log INFO "ASSET_REQUIRES_PROVIDER_ID_HEADER=${ASSET_REQUIRES_PROVIDER_ID_HEADER:-0}"
  lib_log INFO "ASSET_REQUIRES_API_KEY_HEADER=${ASSET_REQUIRES_API_KEY_HEADER:-0}"

  jq -n \
    --arg id "${ASSET_ID}" \
    --arg name "${ASSET_NAME}" \
    --arg description "${ASSET_DESCRIPTION}" \
    --arg content_kind "${ASSET_CONTENT_KIND}" \
    --arg extension "${ASSET_EXTENSION}" \
    --arg media_type "${ASSET_MEDIA_TYPE}" \
    --arg asset_slug "${ASSET_SLUG:-}" \
    --arg base_url "${ASSET_BASE_URL}" \
    --arg data_address_name "${ASSET_DATA_ADDRESS_NAME}" \
    --arg provider_id_header_key "${PHASE1_PROVIDER_ID_HEADER_KEY}" \
    --arg provider_id "${INGESTA_API_PROVIDER_ID:-}" \
    --arg requires_provider_id_header "${ASSET_REQUIRES_PROVIDER_ID_HEADER:-0}" \
    --arg api_key_header_key "${PHASE1_API_KEY_HEADER_KEY}" \
    --arg api_key "${INGESTA_API_KEY:-}" \
    --arg requires_api_key_header "${ASSET_REQUIRES_API_KEY_HEADER:-0}" \
    --argjson keywords "${ASSET_KEYWORDS_JSON}" \
    '{
      "@context": {
        "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
        "dct": "http://purl.org/dc/terms/",
        "dcat": "http://www.w3.org/ns/dcat#"
      },
      "@id": $id,
      "@type": "Asset",
      "properties": ({
        name: $name,
        version: "1.0.0",
        shortDescription: $description,
        assetType: "dataset",
        contentKind: $content_kind,
        extension: $extension,
        mediaType: $media_type,
        "dct:description": $description,
        "dcat:keyword": $keywords
      } + (if $asset_slug != "" then {assetSlug: $asset_slug} else {} end)),
      "dataAddress": ({
        type: "HttpData",
        baseUrl: $base_url,
        name: $data_address_name
      }
      + (if $requires_provider_id_header == "1" then {($provider_id_header_key): $provider_id} else {} end)
      + (if $requires_api_key_header == "1" then {($api_key_header_key): $api_key} else {} end))
    }' > "${tmp}"

  mv "${tmp}" "${dest}"
}

_phase1_append_context_field() {
  local label="$1"
  local value="${2:-}"
  if [[ -n "${value}" ]]; then
    printf '%s=%s\n' "${label}" "${value}"
  fi
}

# ---------------------------------------------------------------------------
# Bootstrap + init
# ---------------------------------------------------------------------------

PHASE1_STEP="init"
api_find_root

if [[ -z "${SUFFIX:-}" ]]; then
  if [[ ! -f "$(lib_phase_env_path 0)" ]]; then
    lib_die "Ejecuta primero phase0_context_smoke.sh"
  fi
  # shellcheck source=/dev/null
  source "$(lib_phase_env_path 0)"
fi

lib_load_env
[[ -n "${ENDPOINTS[vocabulary]:-}" ]] || lib_die "ENDPOINTS[vocabulary] no definido tras cargar endpoints.sh"

lib_require_cmds
lib_require_vars_group LIB_VARS_DATASPACE
lib_require_vars_group LIB_VARS_PROVIDER
lib_require_vars SUFFIX

PHASE1_STEP="load_asset_config"
_phase1_load_asset_config

lib_init_run_dirs
lib_init_summary

# ---------------------------------------------------------------------------
# JWT provider
# ---------------------------------------------------------------------------

PHASE1_STEP="jwt_renew"
lib_renew_jwt provider
lib_jwt_check_console provider

PHASE1_STEP="jwt_claims"
lib_jwt_claims_to_json provider "${PHASE1_DIR}/jwt_claims_provider.json"
lib_write_summary 1 jwt_provider ok '{"artifact":"phase1/jwt_claims_provider.json"}'

# ---------------------------------------------------------------------------
# IDs + contexto
# ---------------------------------------------------------------------------

PHASE1_STEP="derive_ids"
lib_derive_phase1_ids

PHASE1_STEP="write_context"
context_file="${PHASE1_DIR}/00_context.txt"
context_tmp="${context_file}.$$"
{
  printf 'Fecha: %s\n' "$(date)"
  printf 'API_ROOT=%s\n' "${API_ROOT}"
  printf 'SUFFIX=%s\n' "${SUFFIX}"
  printf 'RUN_DIR=%s\n' "${RUN_DIR}"
  printf 'DS_NAME=%s\n' "${DS_NAME}"
  printf 'PROVIDER=%s\n' "${PROVIDER}"
  printf 'PROVIDER_BASE=%s\n' "${PROVIDER_BASE}"
  printf 'PROVIDER_PROTOCOL=%s\n' "${PROVIDER_PROTOCOL}"
  printf 'VOCAB_ID=%s\n' "${VOCAB_ID}"
  printf 'ACCESS_POLICY_ID=%s\n' "${ACCESS_POLICY_ID}"
  printf 'CONTRACT_POLICY_ID=%s\n' "${CONTRACT_POLICY_ID}"
  printf 'ASSET_ID=%s\n' "${ASSET_ID}"
  printf 'CD_ID=%s\n' "${CD_ID}"
  _phase1_append_context_field ASSET_CONFIG "${ASSET_CONFIG:-}"
  _phase1_append_context_field ASSET_SLUG "${ASSET_SLUG:-}"
  _phase1_append_context_field ASSET_NAME "${ASSET_NAME:-}"
  _phase1_append_context_field ASSET_BASE_URL "${ASSET_BASE_URL:-}"
  _phase1_append_context_field ASSET_CONTENT_KIND "${ASSET_CONTENT_KIND:-}"
  _phase1_append_context_field ASSET_EXTENSION "${ASSET_EXTENSION:-}"
  _phase1_append_context_field ASSET_MEDIA_TYPE "${ASSET_MEDIA_TYPE:-}"
  _phase1_append_context_field ASSET_REQUIRES_PROVIDER_ID_HEADER "${ASSET_REQUIRES_PROVIDER_ID_HEADER:-}"
  _phase1_append_context_field ASSET_REQUIRES_API_KEY_HEADER "${ASSET_REQUIRES_API_KEY_HEADER:-}"
} > "${context_tmp}"
mv "${context_tmp}" "${context_file}"

# ---------------------------------------------------------------------------
# Listados iniciales
# ---------------------------------------------------------------------------

_phase1_list_and_summary "01_initial_assets" "asset" "initial_assets"
_phase1_list_and_summary "02_initial_policies" "policyDefinition" "initial_policies"
_phase1_list_and_summary "03_initial_contracts" "contractDefinition" "initial_contracts"
_phase1_list_and_summary "04_initial_vocabularies" "vocabulary" "initial_vocabularies" "${VOCAB_LIST_BODY}"

# ---------------------------------------------------------------------------
# Creaciones (payload guardado como *_request.json, curl con -d @file)
# ---------------------------------------------------------------------------

PHASE1_STEP="create_vocabulary"
vocab_request="${PHASE1_DIR}/10_create_vocabulary_request.json"
_phase1_write_json "${vocab_request}" <<EOF
{
  "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
  "@id": "${VOCAB_ID}",
  "name": "Taller dataset vocabulary ${SUFFIX}",
  "category": "dataset",
  "connectorId": "${PROVIDER}",
  "jsonSchema": "{\"title\":\"Dataset metadata vocabulary\",\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"description\":{\"type\":\"string\"}},\"required\":[\"name\"]}"
}
EOF
_phase1_create_and_summary "10_create_vocabulary" "create_vocabulary" "${vocab_request}" "{}" \
  -X POST "${PROVIDER_BASE}/management/vocabularies"

PHASE1_STEP="create_access_policy"
access_request="${PHASE1_DIR}/11_create_access_policy_request.json"
_phase1_write_json "${access_request}" <<EOF
{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  },
  "@id": "${ACCESS_POLICY_ID}",
  "policy": {
    "@context": "http://www.w3.org/ns/odrl.jsonld",
    "@type": "Set",
    "permission": [
      {
        "action": "USE",
        "constraint": [
          {
            "leftOperand": "PURPOSE",
            "operator": "eq",
            "rightOperand": "research"
          }
        ]
      }
    ],
    "prohibition": [],
    "obligation": []
  }
}
EOF
_phase1_create_and_summary "11_create_access_policy" "create_access_policy" "${access_request}" "{}" \
  -X POST "${PROVIDER_BASE}/management/v3/policydefinitions"

PHASE1_STEP="create_contract_policy"
contract_policy_request="${PHASE1_DIR}/12_create_contract_policy_request.json"
_phase1_write_json "${contract_policy_request}" <<EOF
{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  },
  "@id": "${CONTRACT_POLICY_ID}",
  "policy": {
    "@context": "http://www.w3.org/ns/odrl.jsonld",
    "@type": "Set",
    "permission": [ { "action": "USE" } ],
    "prohibition": [],
    "obligation": []
  }
}
EOF
_phase1_create_and_summary "12_create_contract_policy" "create_contract_policy" "${contract_policy_request}" "{}" \
  -X POST "${PROVIDER_BASE}/management/v3/policydefinitions"

PHASE1_STEP="create_asset"
asset_request="${PHASE1_DIR}/13_create_asset_request.json"
_phase1_ensure_sensitive_tmp_dir
asset_request_raw="${PHASE1_SENSITIVE_TMP_DIR}/13_create_asset_request.json"
(umask 077; _phase1_write_asset_request "${asset_request_raw}")
chmod 600 "${asset_request_raw}"
_phase1_redact_json_file "${asset_request_raw}" "${asset_request}"
_phase1_assert_no_sensitive_artifact "${asset_request}"

create_asset_summary="$(
  jq -nc \
    --arg asset_id "${ASSET_ID}" \
    --arg asset_slug "${ASSET_SLUG:-}" \
    --arg asset_base_url "${ASSET_BASE_URL}" \
    --arg content_kind "${ASSET_CONTENT_KIND}" \
    --arg extension "${ASSET_EXTENSION}" \
    --arg media_type "${ASSET_MEDIA_TYPE}" \
    --arg asset_config "${ASSET_CONFIG:-}" \
    --arg requires_provider_id_header "${ASSET_REQUIRES_PROVIDER_ID_HEADER:-0}" \
    --arg provider_id_header_key "${PHASE1_PROVIDER_ID_HEADER_KEY}" \
    --arg requires_api_key_header "${ASSET_REQUIRES_API_KEY_HEADER:-0}" \
    --arg api_key_header_key "${PHASE1_API_KEY_HEADER_KEY}" \
    '{
      asset_id: $asset_id,
      asset_slug: $asset_slug,
      asset_base_url: $asset_base_url,
      content_kind: $content_kind,
      extension: $extension,
      media_type: $media_type
    }
    + (if $asset_config != "" then {asset_config: $asset_config} else {} end)
    + (if $requires_provider_id_header == "1" then {requires_provider_id_header: true, provider_id_header_key: $provider_id_header_key} else {} end)
    + (if $requires_api_key_header == "1" then {requires_api_key_header: true, api_key_header_key: $api_key_header_key} else {} end)
    + (if $asset_slug != "" then {} else {legacy: true} end)'
)"

if [[ -z "${create_asset_summary}" ]] || ! jq -e . >/dev/null 2>&1 <<< "${create_asset_summary}"; then
  lib_die "create_asset_summary inválido antes de create_asset"
fi

_phase1_create_and_summary "13_create_asset" "create_asset" "${asset_request_raw}" "${create_asset_summary}" \
  -X POST "${PROVIDER_BASE}/management/v3/assets"
_phase1_assert_no_sensitive_artifact "${asset_request}"
_phase1_assert_no_sensitive_artifact "${PHASE1_DIR}/13_create_asset.json"
_phase1_assert_no_sensitive_artifact "${RUN_DIR}/summary.json"

# ---------------------------------------------------------------------------
# Verificaciones post-creación
# ---------------------------------------------------------------------------

PHASE1_STEP="get_asset"
if ! _phase1_curl_json_redacted "${PHASE1_DIR}/14_get_asset" \
  -X GET "${PROVIDER_BASE}/management/v3/assets/${ASSET_ID}" \
  -H "Authorization: Bearer ${PROVIDER_JWT}"; then
  lib_die "GET asset ${ASSET_ID} falló"
fi
get_asset_http="$(tr -d '\n' < "${PHASE1_DIR}/14_get_asset.http")"
lib_write_summary 1 get_asset ok \
  "{\"http\":${get_asset_http},\"artifact\":\"phase1/14_get_asset\"}"
_phase1_assert_no_sensitive_artifact "${PHASE1_DIR}/14_get_asset.json"
_phase1_assert_no_sensitive_artifact "${RUN_DIR}/summary.json"

PHASE1_STEP="create_contract_definition"
cd_request="${PHASE1_DIR}/15_create_contract_definition_request.json"
_phase1_write_json "${cd_request}" <<EOF
{
  "@context": { "@vocab": "https://w3id.org/edc/v0.0.1/ns/" },
  "@id": "${CD_ID}",
  "accessPolicyId": "${ACCESS_POLICY_ID}",
  "contractPolicyId": "${CONTRACT_POLICY_ID}",
  "assetsSelector": [
    {
      "operandLeft": "https://w3id.org/edc/v0.0.1/ns/id",
      "operator": "=",
      "operandRight": "${ASSET_ID}"
    }
  ]
}
EOF
_phase1_create_and_summary "15_create_contract_definition" "create_contract_definition" "${cd_request}" "{}" \
  -X POST "${PROVIDER_BASE}/management/v3/contractdefinitions"

PHASE1_STEP="list_contract_definitions"
lib_curl_json "${PHASE1_DIR}/16_list_contract_definitions" \
  -X POST "${PROVIDER_BASE}${ENDPOINTS[contractDefinition]}" \
  -H "Authorization: Bearer ${PROVIDER_JWT}" \
  -H "Content-Type: application/json" \
  -d "${REQUEST_LIST_BODY}"

jq -e --arg id "${CD_ID}" '.[] | select(."@id" == $id)' \
  "${PHASE1_DIR}/16_list_contract_definitions.json" >/dev/null \
  || lib_die "Contract definition ${CD_ID} no encontrada en listado"

list_cd_http="$(tr -d '\n' < "${PHASE1_DIR}/16_list_contract_definitions.http")"
lib_write_summary 1 list_contract_definitions ok \
  "{\"http\":${list_cd_http},\"artifact\":\"phase1/16_list_contract_definitions\"}"

# ---------------------------------------------------------------------------
# Catálogo local (self-check)
# ---------------------------------------------------------------------------

PHASE1_STEP="self_catalog"
catalog_request="${PHASE1_DIR}/17_self_catalog_request_body.json"
_phase1_write_json "${catalog_request}" <<EOF
{
  "@context": { "@vocab": "https://w3id.org/edc/v0.0.1/ns/" },
  "@type": "CatalogRequest",
  "counterPartyAddress": "${PROVIDER_PROTOCOL}",
  "counterPartyId": "${PROVIDER}",
  "protocol": "dataspace-protocol-http"
}
EOF

_phase1_curl_json_redacted "${PHASE1_DIR}/17_self_catalog_request" \
  -X POST "${PROVIDER_BASE}/management/v3/catalog/request" \
  -H "Authorization: Bearer ${PROVIDER_JWT}" \
  -H "Content-Type: application/json" \
  -d "@${catalog_request}"

catalog_http="$(tr -d '\n' < "${PHASE1_DIR}/17_self_catalog_request.http")"
lib_write_summary 1 self_catalog ok \
  "{\"http\":${catalog_http},\"asset_id\":\"${ASSET_ID}\",\"artifact\":\"phase1/17_self_catalog_request\"}"

PHASE1_STEP="catalog_asset_found"
selected_dataset="${PHASE1_DIR}/selected_self_catalog_dataset.json"
selected_offer="${PHASE1_DIR}/selected_self_offer_policy.json"

_phase1_extract_catalog_dataset \
  "${PHASE1_DIR}/17_self_catalog_request.json" \
  "${selected_dataset}"
_phase1_assert_no_sensitive_artifact "${selected_dataset}"

_phase1_extract_offer_policy "${selected_dataset}" "${selected_offer}"
_phase1_validate_offer_policy "${selected_offer}"

lib_write_summary 1 catalog_asset_found ok \
  "{\"artifact\":\"phase1/selected_self_catalog_dataset.json\",\"offer_artifact\":\"phase1/selected_self_offer_policy.json\"}"

# ---------------------------------------------------------------------------
# Listados finales
# ---------------------------------------------------------------------------

_phase1_list_and_summary "21_final_assets" "asset" "final_assets"
_phase1_list_and_summary "22_final_policies" "policyDefinition" "final_policies"
_phase1_list_and_summary "23_final_contracts" "contractDefinition" "final_contracts"
_phase1_list_and_summary "24_final_vocabularies" "vocabulary" "final_vocabularies" "${VOCAB_LIST_BODY}"

# ---------------------------------------------------------------------------
# Cierre
# ---------------------------------------------------------------------------

PHASE1_STEP="export_env"
lib_export_phase_env 1
_phase1_assert_no_sensitive_artifact "${RUN_DIR}/phase1_env.sh"
_phase1_assert_no_sensitive_artifact "$(lib_phase_env_path 1)"
_phase1_assert_no_sensitive_artifact "${RUN_DIR}/summary.json"
lib_set_phase_status 1 ok

trap - ERR
_phase1_cleanup
lib_log INFO "Fase 1 OK — SUFFIX=${SUFFIX} ASSET_ID=${ASSET_ID} CD_ID=${CD_ID}"
