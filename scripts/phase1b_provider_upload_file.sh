#!/usr/bin/env bash
# phase1b_provider_upload_file.sh — Fase B2: upload local → InesDataStore (provider).
#
# Requisitos: Bash 4.3+, curl, jq (ver scripts/scripts_README.md).
#
# Prerrequisito: phase0 OK.
# Config: ASSET_UPLOAD_CONFIG=asset_configs/demo/upload/ingesta_csv_empresa_demo.json
#
# Uso:
#   source runtime/env/latest/phase0_env.sh
#   ASSET_UPLOAD_CONFIG=asset_configs/demo/upload/ingesta_csv_empresa_demo.json \
#   /opt/homebrew/bin/bash scripts/phase1b_provider_upload_file.sh

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_common.sh
source "${_SCRIPT_DIR}/lib_common.sh"

readonly REQUEST_LIST_BODY='{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"offset":0,"limit":50,"filterExpression":[]}'
readonly VOCAB_LIST_BODY='{}'

PHASE1B_STEP="init"

_phase1b_on_err() {
  local rc=$?
  if [[ -n "${RUN_DIR:-}" && -d "${RUN_DIR}" ]]; then
    lib_write_summary "1b" "${PHASE1B_STEP}" fail "{\"exit_code\":${rc}}" 2>/dev/null || true
    lib_set_phase_status "1b" fail 2>/dev/null || true
  fi
  exit "${rc}"
}
trap _phase1b_on_err ERR

_phase1b_write_json() {
  local dest="$1"
  local tmp="${dest}.$$"
  cat > "${tmp}"
  mv "${tmp}" "${dest}"
}

_phase1b_save_curl_body_as_json_if_valid() {
  local base="$1"
  if [[ -f "${base}.body" ]] && jq empty "${base}.body" 2>/dev/null; then
    cp "${base}.body" "${base}.json"
  fi
}

_phase1b_list_and_summary() {
  local base="$1"
  local endpoint_key="$2"
  local step_id="$3"
  local body="${4:-${REQUEST_LIST_BODY}}"

  PHASE1B_STEP="${step_id}"
  lib_curl_json "${PHASE1B_DIR}/${base}" \
    -X POST "${PROVIDER_BASE}${ENDPOINTS[${endpoint_key}]}" \
    -H "Authorization: Bearer ${PROVIDER_JWT}" \
    -H "Content-Type: application/json" \
    -d "${body}"

  local http count
  http="$(tr -d '\n\r' < "${PHASE1B_DIR}/${base}.http")"
  count="$(jq 'length' "${PHASE1B_DIR}/${base}.json")"
  lib_write_summary "1b" "${step_id}" ok \
    "$(jq -nc --argjson http "${http}" --argjson count "${count}" --arg artifact "phase1b/${base}" \
      '{http: $http, count: $count, artifact: $artifact}')"
}

_phase1b_create_and_summary() {
  local base="$1"
  local step_id="$2"
  local request_file="$3"
  local extra_meta_json="${4-}"
  shift 4

  if [[ -z "${extra_meta_json}" ]]; then
    extra_meta_json='{}'
  fi

  PHASE1B_STEP="${step_id}"
  local http summary_meta

  if ! lib_curl_json "${PHASE1B_DIR}/${base}" \
    -H "Authorization: Bearer ${PROVIDER_JWT}" \
    -H "Content-Type: application/json" \
    -d "@${request_file}" \
    "$@"; then
    http="$(tr -d '\n\r' < "${PHASE1B_DIR}/${base}.http")"
    if [[ "${http}" == "409" ]]; then
      lib_die "HTTP 409: recurso ya existe (SUFFIX=${SUFFIX}, paso=${step_id}). Inicia una ejecución nueva."
    fi
    return 1
  fi

  http="$(tr -d '\n\r' < "${PHASE1B_DIR}/${base}.http")"
  [[ "${http}" =~ ^[0-9]+$ ]] || lib_die "HTTP inválido para ${step_id}: ${http}"

  summary_meta="$(jq -nc \
    --argjson http "${http}" \
    --arg artifact "phase1b/${base}" \
    --arg request "phase1b/$(basename "${request_file}")" \
    --argjson extra "${extra_meta_json}" \
    '{http: $http, artifact: $artifact, request: $request} + $extra')"
  lib_write_summary "1b" "${step_id}" ok "${summary_meta}"
}

_phase1b_sanitize_slug() {
  local slug="$1"
  printf '%s' "${slug}" | sed 's/[^A-Za-z0-9._-]/_/g'
}

_phase1b_jq_string() {
  local config_file="$1"
  local field="$2"
  local value
  value="$(jq -r --arg f "${field}" '.[$f] // empty | select(type == "string" and length > 0)' "${config_file}")"
  [[ -n "${value}" ]] || lib_die "ASSET_UPLOAD_CONFIG: campo obligatorio '${field}' vacío o ausente"
  printf '%s' "${value}"
}

_phase1b_jq_array_json() {
  local config_file="$1"
  local field="${2:-keywords}"
  local value

  if ! value="$(
    jq -ce --arg field "${field}" '
      (.[$field] // [])
      | if type != "array" then error($field + " debe ser un array") else . end
      | if all(.[]; type == "string") then . else error($field + " debe ser array de strings") end
    ' "${config_file}"
  )"; then
    lib_die "Campo ${field} inválido en ${config_file}"
  fi
  [[ -n "${value}" ]] || value='[]'
  printf '%s' "${value}"
}

_phase1b_extension_allowed() {
  case "${1}" in
    csv|txt|xml|gml|ttl|rdf|xlsx|zip) return 0 ;;
    *) return 1 ;;
  esac
}

_phase1b_validate_upload_config() {
  local config_file="$1"

  jq empty "${config_file}" || lib_die "ASSET_UPLOAD_CONFIG no es JSON válido"

  local storage_mode asset_type content_kind extension
  storage_mode="$(_phase1b_jq_string "${config_file}" storage_mode)"
  asset_type="$(_phase1b_jq_string "${config_file}" type)"
  [[ "${storage_mode}" == "inesdatastore" ]] \
    || lib_die "storage_mode debe ser inesdatastore (recibido: ${storage_mode})"
  [[ "${asset_type}" == "InesDataStore" ]] \
    || lib_die "type debe ser InesDataStore (recibido: ${asset_type})"

  content_kind="$(_phase1b_jq_string "${config_file}" content_kind)"
  extension="$(_phase1b_jq_string "${config_file}" extension)"
  case "${content_kind}" in
    text|binary) ;;
    *) lib_die "content_kind debe ser text o binary (recibido: ${content_kind})" ;;
  esac
  _phase1b_extension_allowed "${extension}" \
    || lib_die "extension no permitida para B2 MVP: ${extension}"

  case "${content_kind}" in
    text)
      case "${extension}" in csv|txt|xml|gml|ttl|rdf) return 0 ;; *)
        lib_die "content_kind=text requiere extension csv,txt,xml,gml,ttl o rdf" ;;
      esac
      ;;
    binary)
      case "${extension}" in xlsx|zip) return 0 ;; *)
        lib_die "content_kind=binary requiere extension xlsx o zip" ;;
      esac
      ;;
  esac
}

_phase1b_default_media_type() {
  case "${1}" in
    csv) printf '%s' 'text/csv' ;;
    txt) printf '%s' 'text/plain' ;;
    xml) printf '%s' 'application/xml' ;;
    gml) printf '%s' 'application/gml+xml' ;;
    xlsx) printf '%s' 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ;;
    zip) printf '%s' 'application/zip' ;;
    ttl) printf '%s' 'text/turtle' ;;
    rdf) printf '%s' 'application/rdf+xml' ;;
    *) lib_die "no hay media_type por defecto para extension=${1}" ;;
  esac
}

_phase1b_load_upload_config() {
  [[ -n "${ASSET_UPLOAD_CONFIG:-}" ]] \
    || lib_die "Export ASSET_UPLOAD_CONFIG (p. ej. asset_configs/demo/upload/ingesta_csv_empresa_demo.json)"

  local config_path="${ASSET_UPLOAD_CONFIG}"
  if [[ "${config_path}" != /* ]]; then
    config_path="${API_ROOT}/${config_path}"
  fi
  [[ -f "${config_path}" ]] || lib_die "ASSET_UPLOAD_CONFIG no encontrado: ${config_path}"

  _phase1b_validate_upload_config "${config_path}"

  local raw_slug safe_slug config_asset_id media_type
  raw_slug="$(_phase1b_jq_string "${config_path}" asset_slug)"
  safe_slug="$(_phase1b_sanitize_slug "${raw_slug}")"
  [[ -n "${safe_slug}" ]] || lib_die "asset_slug inválido tras sanitizar"

  config_asset_id="$(jq -r '.asset_id // empty | select(type == "string" and length > 0)' "${config_path}")"
  if [[ -n "${config_asset_id}" ]]; then
    [[ "${config_asset_id}" =~ ^[A-Za-z0-9._-]+$ ]] \
      || lib_die "asset_id contiene caracteres no permitidos"
    export ASSET_ID="${config_asset_id}"
  else
    export ASSET_ID="${safe_slug}-${SUFFIX}"
  fi

  LOCAL_FILE="$(_phase1b_jq_string "${config_path}" local_file)"
  if [[ "${LOCAL_FILE}" != /* ]]; then
    LOCAL_FILE="${API_ROOT}/${LOCAL_FILE}"
  fi
  [[ -f "${LOCAL_FILE}" ]] || lib_die "LOCAL_FILE no encontrado: ${LOCAL_FILE}"

  STORE_FOLDER="$(_phase1b_jq_string "${config_path}" store_folder)"
  UPLOAD_FILE_NAME="$(_phase1b_jq_string "${config_path}" upload_file_name)"
  FINALIZE_FILE_NAME="$(jq -r '.finalize_file_name // empty' "${config_path}")"
  if [[ -z "${FINALIZE_FILE_NAME}" ]]; then
    FINALIZE_FILE_NAME="${STORE_FOLDER}/${UPLOAD_FILE_NAME}"
  fi

  media_type="$(jq -r '.media_type // empty | select(type == "string" and length > 0)' "${config_path}")"
  if [[ -z "${media_type}" ]]; then
    media_type="$(_phase1b_default_media_type "$(_phase1b_jq_string "${config_path}" extension)")"
  fi

  export ASSET_ID_CUSTOM=1
  export ASSET_UPLOAD_CONFIG="${ASSET_UPLOAD_CONFIG}"
  export STORAGE_MODE="inesdatastore"
  export ASSET_SLUG="${safe_slug}"
  export ASSET_NAME="$(_phase1b_jq_string "${config_path}" name)"
  export ASSET_DESCRIPTION="$(_phase1b_jq_string "${config_path}" description)"
  export ASSET_CONTENT_KIND="$(_phase1b_jq_string "${config_path}" content_kind)"
  export ASSET_EXTENSION="$(_phase1b_jq_string "${config_path}" extension)"
  export ASSET_MEDIA_TYPE="${media_type}"
  export ASSET_KEYWORDS_JSON="$(_phase1b_jq_array_json "${config_path}" keywords)"
  export LOCAL_FILE STORE_FOLDER UPLOAD_FILE_NAME FINALIZE_FILE_NAME
}

_phase1b_write_upload_asset_request() {
  local dest="$1"
  local tmp="${dest}.$$"

  jq -n \
    --arg id "${ASSET_ID}" \
    --arg name "${ASSET_NAME}" \
    --arg description "${ASSET_DESCRIPTION}" \
    --arg content_kind "${ASSET_CONTENT_KIND}" \
    --arg extension "${ASSET_EXTENSION}" \
    --arg media_type "${ASSET_MEDIA_TYPE}" \
    --arg asset_slug "${ASSET_SLUG}" \
    --arg folder "${STORE_FOLDER}" \
    --argjson keywords "${ASSET_KEYWORDS_JSON}" \
    '{
      "@context": {
        "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
        "dct": "http://purl.org/dc/terms/",
        "dcat": "http://www.w3.org/ns/dcat#"
      },
      "@id": $id,
      "@type": "Asset",
      "properties": {
        name: $name,
        version: "1.0.0",
        shortDescription: $description,
        assetType: "dataset",
        contentKind: $content_kind,
        extension: $extension,
        mediaType: $media_type,
        assetSlug: $asset_slug,
        "dct:description": $description,
        "dcat:keyword": $keywords
      },
      "dataAddress": {
        "type": "InesDataStore",
        "folder": $folder
      }
    }' > "${tmp}"

  mv "${tmp}" "${dest}"
}

_phase1b_export_env_for_phase2() {
  local -a vars=(
    SUFFIX VOCAB_ID ACCESS_POLICY_ID CONTRACT_POLICY_ID ASSET_ID CD_ID
    ASSET_ID_CUSTOM ASSET_UPLOAD_CONFIG ASSET_SLUG ASSET_NAME ASSET_DESCRIPTION
    ASSET_CONTENT_KIND ASSET_EXTENSION ASSET_MEDIA_TYPE ASSET_KEYWORDS_JSON
    STORAGE_MODE LOCAL_FILE STORE_FOLDER UPLOAD_FILE_NAME FINALIZE_FILE_NAME
  )
  _lib_backup_env_file_if_needed "$(lib_phase_env_path 1)" "${SUFFIX}"
  _lib_write_env_file "$(lib_phase_env_path 1)" "${vars[@]}"
  _lib_write_env_file "${RUN_DIR}/phase1_env.sh" "${vars[@]}"
  lib_log INFO "Escrito $(lib_phase_env_path 1) (compat phase2)"
}

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

PHASE1B_STEP="init"
api_find_root

if [[ -z "${SUFFIX:-}" ]]; then
  if [[ ! -f "$(lib_phase_env_path 0)" ]]; then
    lib_die "Ejecuta primero phase0_context_smoke.sh"
  fi
  # shellcheck source=/dev/null
  source "$(lib_phase_env_path 0)"
fi

lib_load_env
lib_require_cmds
lib_require_vars_group LIB_VARS_DATASPACE
lib_require_vars_group LIB_VARS_PROVIDER
lib_require_vars SUFFIX

PHASE1B_STEP="load_upload_config"
_phase1b_load_upload_config

lib_init_run_dirs
lib_init_summary

PHASE1B_STEP="jwt_renew"
lib_renew_jwt provider
lib_jwt_check_console provider

PHASE1B_STEP="derive_ids"
lib_derive_phase1_ids

PHASE1B_STEP="write_context"
{
  printf 'Fecha: %s\n' "$(date)"
  printf 'SUFFIX=%s\n' "${SUFFIX}"
  printf 'STORAGE_MODE=%s\n' "${STORAGE_MODE}"
  printf 'ASSET_UPLOAD_CONFIG=%s\n' "${ASSET_UPLOAD_CONFIG}"
  printf 'ASSET_ID=%s\n' "${ASSET_ID}"
  printf 'LOCAL_FILE=%s\n' "${LOCAL_FILE}"
  printf 'STORE_FOLDER=%s\n' "${STORE_FOLDER}"
  printf 'UPLOAD_FILE_NAME=%s\n' "${UPLOAD_FILE_NAME}"
  printf 'FINALIZE_FILE_NAME=%s\n' "${FINALIZE_FILE_NAME}"
  printf 'ASSET_CONTENT_KIND=%s\n' "${ASSET_CONTENT_KIND}"
  printf 'ASSET_EXTENSION=%s\n' "${ASSET_EXTENSION}"
} > "${PHASE1B_DIR}/00_context.txt"

# ---------------------------------------------------------------------------
# Policies + vocabulary (sin POST /assets)
# ---------------------------------------------------------------------------

_phase1b_list_and_summary "01_initial_assets" "asset" "initial_assets"
_phase1b_list_and_summary "02_initial_policies" "policyDefinition" "initial_policies"
_phase1b_list_and_summary "03_initial_contracts" "contractDefinition" "initial_contracts"

PHASE1B_STEP="create_vocabulary"
vocab_request="${PHASE1B_DIR}/10_create_vocabulary_request.json"
_phase1b_write_json "${vocab_request}" <<EOF
{
  "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"},
  "@id": "${VOCAB_ID}",
  "name": "Taller upload vocabulary ${SUFFIX}",
  "category": "dataset",
  "connectorId": "${PROVIDER}",
  "jsonSchema": "{\"title\":\"Upload metadata\",\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}}}"
}
EOF
_phase1b_create_and_summary "10_create_vocabulary" "create_vocabulary" "${vocab_request}" "{}" \
  -X POST "${PROVIDER_BASE}/management/vocabularies"

PHASE1B_STEP="create_access_policy"
access_request="${PHASE1B_DIR}/11_create_access_policy_request.json"
_phase1b_write_json "${access_request}" <<EOF
{
  "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/", "odrl": "http://www.w3.org/ns/odrl/2/"},
  "@id": "${ACCESS_POLICY_ID}",
  "policy": {
    "@context": "http://www.w3.org/ns/odrl.jsonld",
    "@type": "Set",
    "permission": [{"action": "USE", "constraint": [{"leftOperand": "PURPOSE", "operator": "eq", "rightOperand": "research"}]}],
    "prohibition": [],
    "obligation": []
  }
}
EOF
_phase1b_create_and_summary "11_create_access_policy" "create_access_policy" "${access_request}" "{}" \
  -X POST "${PROVIDER_BASE}/management/v3/policydefinitions"

PHASE1B_STEP="create_contract_policy"
contract_policy_request="${PHASE1B_DIR}/12_create_contract_policy_request.json"
_phase1b_write_json "${contract_policy_request}" <<EOF
{
  "@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/", "odrl": "http://www.w3.org/ns/odrl/2/"},
  "@id": "${CONTRACT_POLICY_ID}",
  "policy": {
    "@context": "http://www.w3.org/ns/odrl.jsonld",
    "@type": "Set",
    "permission": [{"action": "USE"}],
    "prohibition": [],
    "obligation": []
  }
}
EOF
_phase1b_create_and_summary "12_create_contract_policy" "create_contract_policy" "${contract_policy_request}" "{}" \
  -X POST "${PROVIDER_BASE}/management/v3/policydefinitions"

# ---------------------------------------------------------------------------
# Upload InesDataStore
# ---------------------------------------------------------------------------

PHASE1B_STEP="build_upload_request"
upload_asset_request="${PHASE1B_DIR}/13_upload_asset_request.json"
_phase1b_write_upload_asset_request "${upload_asset_request}"

PHASE1B_STEP="upload_chunk"
upload_chunk_base="${PHASE1B_DIR}/13_upload_chunk"
if ! lib_curl_save "${upload_chunk_base}" \
  -X POST "${PROVIDER_BASE}/management/s3assets/upload-chunk" \
  -H "Authorization: Bearer ${PROVIDER_JWT}" \
  -H "Content-Disposition: attachment; filename=\"${UPLOAD_FILE_NAME}\"" \
  -H "Chunk-Index: 0" \
  -H "Total-Chunks: 1" \
  -F "json=@${upload_asset_request};type=application/json" \
  -F "file=@${LOCAL_FILE};type=${ASSET_MEDIA_TYPE}"; then
  lib_die "upload-chunk falló — revisar ${upload_chunk_base}.body"
fi
_phase1b_save_curl_body_as_json_if_valid "${upload_chunk_base}"
upload_chunk_http="$(tr -d '\n\r' < "${upload_chunk_base}.http")"
lib_write_summary "1b" upload_chunk ok \
  "$(jq -nc --argjson http "${upload_chunk_http}" --arg artifact "phase1b/13_upload_chunk" \
    '{http: $http, artifact: $artifact, chunks: 1}')"

PHASE1B_STEP="finalize_upload"
finalize_base="${PHASE1B_DIR}/14_finalize_upload"
if ! lib_curl_save "${finalize_base}" \
  -X POST "${PROVIDER_BASE}/management/s3assets/finalize-upload" \
  -H "Authorization: Bearer ${PROVIDER_JWT}" \
  -F "json=@${upload_asset_request};type=application/json" \
  -F "fileName=${FINALIZE_FILE_NAME}"; then
  lib_die "finalize-upload falló — revisar ${finalize_base}.body"
fi
_phase1b_save_curl_body_as_json_if_valid "${finalize_base}"
finalize_http="$(tr -d '\n\r' < "${finalize_base}.http")"
lib_write_summary "1b" finalize_upload ok \
  "$(jq -nc \
    --argjson http "${finalize_http}" \
    --arg finalize_file_name "${FINALIZE_FILE_NAME}" \
    --arg artifact "phase1b/14_finalize_upload" \
    '{http: $http, finalize_file_name: $finalize_file_name, artifact: $artifact}')"

PHASE1B_STEP="get_asset"
if ! lib_curl_json "${PHASE1B_DIR}/15_get_asset" \
  -X GET "${PROVIDER_BASE}/management/v3/assets/${ASSET_ID}" \
  -H "Authorization: Bearer ${PROVIDER_JWT}"; then
  lib_die "GET asset ${ASSET_ID} falló tras finalize"
fi
get_asset_http="$(tr -d '\n\r' < "${PHASE1B_DIR}/15_get_asset.http")"
lib_write_summary "1b" get_asset ok \
  "$(jq -nc --argjson http "${get_asset_http}" --arg artifact "phase1b/15_get_asset" --arg asset_id "${ASSET_ID}" \
    '{http: $http, artifact: $artifact, asset_id: $asset_id}')"

PHASE1B_STEP="create_contract_definition"
cd_request="${PHASE1B_DIR}/16_create_contract_definition_request.json"
_phase1b_write_json "${cd_request}" <<EOF
{
  "@context": { "@vocab": "https://w3id.org/edc/v0.0.1/ns/" },
  "@id": "${CD_ID}",
  "accessPolicyId": "${ACCESS_POLICY_ID}",
  "contractPolicyId": "${CONTRACT_POLICY_ID}",
  "assetsSelector": [{
    "operandLeft": "https://w3id.org/edc/v0.0.1/ns/id",
    "operator": "=",
    "operandRight": "${ASSET_ID}"
  }]
}
EOF
_phase1b_create_and_summary "16_create_contract_definition" "create_contract_definition" "${cd_request}" "{}" \
  -X POST "${PROVIDER_BASE}/management/v3/contractdefinitions"

# ---------------------------------------------------------------------------
# Cierre
# ---------------------------------------------------------------------------

PHASE1B_STEP="export_env"
_phase1b_export_env_for_phase2
lib_export_phase_env 1b
lib_set_phase_status "1b" ok

trap - ERR
lib_log INFO "Fase 1b OK — SUFFIX=${SUFFIX} ASSET_ID=${ASSET_ID} STORAGE_MODE=${STORAGE_MODE}"
