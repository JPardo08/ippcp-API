#!/usr/bin/env bash
# phase4_save_download.sh — Fase 4: materializar descarga local desde artefactos Fase 3.
#
# Requisitos: Bash 4.3+, jq, shasum u openssl (ver scripts/scripts_README.md).
# No hace llamadas al dataspace (sin curl EdD, sin JWT, sin EDR).
#
# Prerrequisito: phase3 OK (phase3_env.sh o variables exportadas).
# Sobrescribir descarga existente con hash distinto: DOWNLOAD_FORCE=1
#
# Uso:
#   source runtime/env/latest/phase3_env.sh
#   /opt/homebrew/bin/bash scripts/phase4_save_download.sh

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_common.sh
source "${_SCRIPT_DIR}/lib_common.sh"

PHASE4_STEP="init"
COPY_ACTION=""

_phase4_on_err() {
  local rc=$?
  if [[ -n "${RUN_DIR:-}" && -d "${RUN_DIR}" ]]; then
    lib_write_summary 4 "${PHASE4_STEP}" fail "{\"exit_code\":${rc}}" 2>/dev/null || true
    lib_set_phase_status 4 fail 2>/dev/null || true
  fi
  exit "${rc}"
}
trap _phase4_on_err ERR

_phase4_id_is_set() {
  local value="${1:-}"
  [[ -n "${value}" && "${value}" != "null" ]]
}

_phase4_require_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    return 0
  fi
  lib_die "Se requiere shasum -a 256 u openssl para calcular SHA256"
}

_phase4_sha256_file() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
    return 0
  fi
  openssl dgst -sha256 "${file}" | awk '{print $NF}'
}

_phase4_file_bytes() {
  local file="$1"
  wc -c < "${file}" | tr -d ' '
}

_phase4_sanitize_asset_id() {
  local asset_id="$1"
  printf '%s' "${asset_id}" | sed 's/[^A-Za-z0-9._-]/_/g'
}

_phase4_atomic_copy() {
  local src="$1"
  local dest="$2"
  local tmp="${dest}.$$"
  cp "${src}" "${tmp}"
  mv "${tmp}" "${dest}"
}

_phase4_atomic_write() {
  local dest="$1"
  shift
  local tmp="${dest}.$$"
  cat > "${tmp}"
  mv "${tmp}" "${dest}"
}

_phase4_extension_allowed() {
  case "${1}" in
    json|xml|gml|csv|txt|ttl|rdf|xlsx|zip) return 0 ;;
    *) return 1 ;;
  esac
}

_phase4_validate_content_kind_value() {
  case "${1}" in
    json|text|binary) return 0 ;;
    *)
      lib_die "ASSET_CONTENT_KIND debe ser json, text o binary (recibido: ${1})"
      ;;
  esac
}

_phase4_validate_extension_value() {
  _phase4_extension_allowed "${1}" \
    || lib_die "ASSET_EXTENSION no permitida (recibido: ${1}). Permitidas: json, xml, gml, csv, txt, ttl, rdf, xlsx, zip"
}

_phase4_validate_kind_extension_pair() {
  local content_kind="$1"
  local extension="$2"

  case "${content_kind}" in
    json)
      [[ "${extension}" == "json" ]] \
        || lib_die "ASSET_CONTENT_KIND=json requiere ASSET_EXTENSION=json (recibido: ${extension})"
      ;;
    text)
      case "${extension}" in
        xml|gml|csv|txt|ttl|rdf) return 0 ;;
        *)
          lib_die "ASSET_CONTENT_KIND=text requiere ASSET_EXTENSION xml,gml,csv,txt,ttl o rdf (recibido: ${extension})"
          ;;
      esac
      ;;
    binary)
      case "${extension}" in
        xlsx|zip) return 0 ;;
        *)
          lib_die "ASSET_CONTENT_KIND=binary requiere ASSET_EXTENSION xlsx o zip (recibido: ${extension})"
          ;;
      esac
      ;;
  esac
}

_phase4_apply_asset_content_defaults() {
  ASSET_CONTENT_KIND="${ASSET_CONTENT_KIND:-json}"
  ASSET_EXTENSION="${ASSET_EXTENSION:-json}"
  ASSET_MEDIA_TYPE="${ASSET_MEDIA_TYPE:-application/json}"

  _phase4_validate_content_kind_value "${ASSET_CONTENT_KIND}"
  _phase4_validate_extension_value "${ASSET_EXTENSION}"
  _phase4_validate_kind_extension_pair "${ASSET_CONTENT_KIND}" "${ASSET_EXTENSION}"

  export ASSET_CONTENT_KIND ASSET_EXTENSION ASSET_MEDIA_TYPE
}

_phase4_resolve_source_data_file() {
  local primary="${PHASE3_DIR}/40_data_response.${ASSET_EXTENSION}"

  if [[ -f "${primary}" ]]; then
    printf '%s' "${primary}"
    return 0
  fi

  if [[ "${ASSET_EXTENSION}" == "json" && -f "${PHASE3_DIR}/40_data_response.json" ]]; then
    printf '%s' "${PHASE3_DIR}/40_data_response.json"
    return 0
  fi

  lib_die "No existe ${primary} (¿Fase 3 completada con data_consumed?)"
}

_phase4_validate_prerequisites() {
  local summary_file="${RUN_DIR}/summary.json"

  SOURCE_DATA_FILE="$(_phase4_resolve_source_data_file)"
  SOURCE_HTTP="${PHASE3_DIR}/40_data_response.http"

  [[ -f "${SOURCE_HTTP}" ]] \
    || lib_die "No existe ${SOURCE_HTTP}"

  DATA_HTTP="$(tr -d '\n\r' < "${SOURCE_HTTP}")"
  [[ "${DATA_HTTP}" =~ ^2[0-9]{2}$ ]] \
    || lib_die "HTTP ${DATA_HTTP} en 40_data_response.http — se esperaba 2xx"

  if [[ "${ASSET_CONTENT_KIND}" == "json" ]]; then
    jq empty "${SOURCE_DATA_FILE}" \
      || lib_die "${SOURCE_DATA_FILE} no es JSON válido"
  else
    local bytes
    bytes="$(_phase4_file_bytes "${SOURCE_DATA_FILE}")"
    if (( bytes == 0 )) && [[ "${ALLOW_EMPTY_DOWNLOAD:-}" != "1" ]]; then
      lib_die "${SOURCE_DATA_FILE} está vacío (export ALLOW_EMPTY_DOWNLOAD=1 para permitir)"
    fi
  fi

  [[ -f "${summary_file}" ]] \
    || lib_die "No existe ${summary_file}"

  jq -e '.phases.phase3.status == "ok"' "${summary_file}" >/dev/null \
    || lib_die "summary.json: phases.phase3.status != ok"

  lib_require_vars SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL
}

_phase4_write_manifest() {
  local dest="$1"
  local tmp="${dest}.$$"

  jq -n \
    --arg suffix "${SUFFIX}" \
    --arg asset_id "${ASSET_ID}" \
    --arg agreement_id "${AGREEMENT_ID}" \
    --arg transfer_id "${TRANSFER_ID}" \
    --arg edr_url "${EDR_URL}" \
    --arg content_kind "${ASSET_CONTENT_KIND}" \
    --arg extension "${ASSET_EXTENSION}" \
    --arg media_type "${ASSET_MEDIA_TYPE}" \
    --arg source_artifact "evidencias/runs/${SUFFIX}/phase3/40_data_response.${ASSET_EXTENSION}" \
    --arg download_file "downloads/assets/${SAFE_ASSET_ID}/${SUFFIX}.${ASSET_EXTENSION}" \
    --arg latest_file "downloads/assets/${SAFE_ASSET_ID}/latest.${ASSET_EXTENSION}" \
    --arg manifest_file "downloads/manifests/${SAFE_ASSET_ID}/${SUFFIX}.manifest.json" \
    --arg latest_manifest "downloads/manifests/${SAFE_ASSET_ID}/latest.manifest.json" \
    --argjson bytes "${FILE_BYTES}" \
    --arg sha256 "${FILE_SHA256}" \
    --arg created_at "$(lib_now_iso)" \
    --arg phase3_status "ok" \
    --argjson data_http "${DATA_HTTP}" \
    --arg copy_action "${COPY_ACTION}" \
    '{
      suffix: $suffix,
      asset_id: $asset_id,
      agreement_id: $agreement_id,
      transfer_id: $transfer_id,
      edr_url: $edr_url,
      content_kind: $content_kind,
      extension: $extension,
      media_type: $media_type,
      source_artifact: $source_artifact,
      download_file: $download_file,
      latest_file: $latest_file,
      manifest_file: $manifest_file,
      latest_manifest: $latest_manifest,
      bytes: $bytes,
      sha256: $sha256,
      created_at: $created_at,
      phase3_status: $phase3_status,
      data_http: $data_http,
      copy_action: $copy_action
    }' > "${tmp}"

  mv "${tmp}" "${dest}"
}

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

PHASE4_STEP="init"
api_find_root

if ! _phase4_id_is_set "${SUFFIX:-}" \
  || ! _phase4_id_is_set "${ASSET_ID:-}" \
  || ! _phase4_id_is_set "${AGREEMENT_ID:-}" \
  || ! _phase4_id_is_set "${TRANSFER_ID:-}" \
  || ! _phase4_id_is_set "${EDR_URL:-}"; then
  if [[ ! -f "$(lib_phase_env_path 3)" ]]; then
    lib_die "Ejecuta primero phase3_transfer_edr.sh"
  fi
  # shellcheck source=/dev/null
  source "$(lib_phase_env_path 3)"
fi

lib_load_env
lib_require_cmds
_phase4_require_sha256
lib_require_vars SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL
_phase4_apply_asset_content_defaults
lib_init_run_dirs
lib_init_summary

PHASE4_DIR="${RUN_DIR}/phase4"
DOWNLOADS_DIR="${API_ROOT}/downloads"
mkdir -p "${PHASE4_DIR}" "${DOWNLOADS_DIR}"
export PHASE4_DIR DOWNLOADS_DIR

# ---------------------------------------------------------------------------
# Validaciones
# ---------------------------------------------------------------------------

PHASE4_STEP="validate"
_phase4_validate_prerequisites

SAFE_ASSET_ID="$(_phase4_sanitize_asset_id "${ASSET_ID}")"
ASSET_DOWNLOAD_DIR="${DOWNLOADS_DIR}/assets/${SAFE_ASSET_ID}"
MANIFEST_DOWNLOAD_DIR="${DOWNLOADS_DIR}/manifests/${SAFE_ASSET_ID}"

mkdir -p "${ASSET_DOWNLOAD_DIR}" "${MANIFEST_DOWNLOAD_DIR}"
export ASSET_DOWNLOAD_DIR MANIFEST_DOWNLOAD_DIR

DOWNLOAD_FILE="${ASSET_DOWNLOAD_DIR}/${SUFFIX}.${ASSET_EXTENSION}"
LATEST_FILE="${ASSET_DOWNLOAD_DIR}/latest.${ASSET_EXTENSION}"

MANIFEST_FILE="${MANIFEST_DOWNLOAD_DIR}/${SUFFIX}.manifest.json"
LATEST_MANIFEST="${MANIFEST_DOWNLOAD_DIR}/latest.manifest.json"

SOURCE_SHA256="$(_phase4_sha256_file "${SOURCE_DATA_FILE}")"

if [[ ! -f "${DOWNLOAD_FILE}" ]]; then
  COPY_ACTION="created"
elif [[ "$(_phase4_sha256_file "${DOWNLOAD_FILE}")" == "${SOURCE_SHA256}" ]]; then
  COPY_ACTION="already_exists_same_hash"
  lib_log INFO "Destino ya existe con mismo SHA256; no se sobrescribe ${DOWNLOAD_FILE}"
else
  if [[ "${DOWNLOAD_FORCE:-}" != "1" ]]; then
    lib_die "Destino ${DOWNLOAD_FILE} existe con contenido distinto. Export DOWNLOAD_FORCE=1 para sobrescribir."
  fi
  COPY_ACTION="overwritten"
fi

# ---------------------------------------------------------------------------
# Copiar descarga
# ---------------------------------------------------------------------------

PHASE4_STEP="save_download"

if [[ "${COPY_ACTION}" != "already_exists_same_hash" ]]; then
  _phase4_atomic_copy "${SOURCE_DATA_FILE}" "${DOWNLOAD_FILE}"
fi

_phase4_atomic_copy "${DOWNLOAD_FILE}" "${LATEST_FILE}"

FILE_SHA256="$(_phase4_sha256_file "${DOWNLOAD_FILE}")"
FILE_BYTES="$(_phase4_file_bytes "${DOWNLOAD_FILE}")"

# ---------------------------------------------------------------------------
# Manifests
# ---------------------------------------------------------------------------

PHASE4_STEP="write_manifest"
_phase4_write_manifest "${MANIFEST_FILE}"
_phase4_write_manifest "${LATEST_MANIFEST}"
_phase4_write_manifest "${PHASE4_DIR}/download_manifest.json"
_phase4_write_manifest "${PHASE4_DIR}/download_summary.json"

# ---------------------------------------------------------------------------
# Cierre
# ---------------------------------------------------------------------------

PHASE4_STEP="export_summary"
lib_write_summary 4 save_download ok \
  "$(jq -nc \
    --arg download_file "downloads/assets/${SAFE_ASSET_ID}/${SUFFIX}.${ASSET_EXTENSION}" \
    --arg latest_file "downloads/assets/${SAFE_ASSET_ID}/latest.${ASSET_EXTENSION}" \
    --arg manifest_file "downloads/manifests/${SAFE_ASSET_ID}/${SUFFIX}.manifest.json" \
    --arg latest_manifest "downloads/manifests/${SAFE_ASSET_ID}/latest.manifest.json" \
    --arg content_kind "${ASSET_CONTENT_KIND}" \
    --arg extension "${ASSET_EXTENSION}" \
    --arg media_type "${ASSET_MEDIA_TYPE}" \
    --arg sha256 "${FILE_SHA256}" \
    --arg copy_action "${COPY_ACTION}" \
    --argjson bytes "${FILE_BYTES}" \
    --argjson data_http "${DATA_HTTP}" \
    '{
      download_file: $download_file,
      latest_file: $latest_file,
      manifest: "phase4/download_manifest.json",
      manifest_file: $manifest_file,
      latest_manifest: $latest_manifest,
      content_kind: $content_kind,
      extension: $extension,
      media_type: $media_type,
      sha256: $sha256,
      copy_action: $copy_action,
      bytes: $bytes,
      data_http: $data_http
    }')"

lib_set_phase_status 4 ok

trap - ERR
lib_log INFO "Fase 4 OK — download_file=downloads/assets/${SAFE_ASSET_ID}/latest.${ASSET_EXTENSION} sha256=${FILE_SHA256}"
