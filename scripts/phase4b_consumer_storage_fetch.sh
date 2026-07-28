#!/usr/bin/env bash
# Historical T1 B2/CSV reproducibility path; not current T4 ingestion.
# phase4b_consumer_storage_fetch.sh — Fase B2: descarga desde MinIO consumer vía mc.
#
# Lee credenciales S3 de phase3b/21_transfer_final_state.sensitive.json (preferido).
# Prerrequisito: phase3b OK (phase3b_env.sh).
#
# Uso:
#   source runtime/env/latest/phase3b_env.sh
#   /opt/homebrew/bin/bash scripts/phase4b_consumer_storage_fetch.sh
#
# Escape hatch MVP: PHASE4B_ALLOW_SKIP=1 → skipped exit 0 si faltan credenciales.

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_common.sh
source "${_SCRIPT_DIR}/lib_common.sh"

PHASE4B_STEP="init"
COPY_ACTION=""
MC_CONFIG_DIR=""

_phase4b_on_err() {
  local rc=$?
  if [[ -n "${RUN_DIR:-}" && -d "${RUN_DIR}" ]]; then
    lib_write_summary "4b" "${PHASE4B_STEP}" fail "{\"exit_code\":${rc}}" 2>/dev/null || true
    lib_set_phase_status "4b" fail 2>/dev/null || true
  fi
  exit "${rc}"
}

_phase4b_cleanup() {
  if [[ -n "${MC_CONFIG_DIR:-}" && -d "${MC_CONFIG_DIR}" ]]; then
    rm -rf "${MC_CONFIG_DIR}"
  fi
  unset ACCESS_KEY SECRET_KEY 2>/dev/null || true
}

trap _phase4b_on_err ERR
trap _phase4b_cleanup EXIT

_phase4b_require_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    return 0
  fi
  lib_die "Se requiere shasum -a 256 u openssl para calcular SHA256"
}

_phase4b_require_mc() {
  command -v mc >/dev/null 2>&1 \
    || lib_die "mc no encontrado en PATH. Instala: brew install minio/stable/mc"
}

_phase4b_sha256_file() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
    return 0
  fi
  openssl dgst -sha256 "${file}" | awk '{print $NF}'
}

_phase4b_file_bytes() {
  local file="$1"
  wc -c < "${file}" | tr -d ' '
}

_phase4b_sanitize_asset_id() {
  local asset_id="$1"
  printf '%s' "${asset_id}" | sed 's/[^A-Za-z0-9._-]/_/g'
}

_phase4b_extension_allowed() {
  case "${1}" in
    json|xml|gml|csv|txt|ttl|rdf|xlsx|zip) return 0 ;;
    *) return 1 ;;
  esac
}

_phase4b_validate_content_kind_value() {
  case "${1}" in
    json|text|binary) return 0 ;;
    *)
      lib_die "ASSET_CONTENT_KIND debe ser json, text o binary (recibido: ${1})"
      ;;
  esac
}

_phase4b_validate_extension_value() {
  _phase4b_extension_allowed "${1}" \
    || lib_die "ASSET_EXTENSION no permitida (recibido: ${1}). Permitidas: json, xml, gml, csv, txt, ttl, rdf, xlsx, zip"
}

_phase4b_validate_kind_extension_pair() {
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

_phase4b_apply_asset_content_defaults() {
  ASSET_CONTENT_KIND="${ASSET_CONTENT_KIND:-csv}"
  ASSET_EXTENSION="${ASSET_EXTENSION:-csv}"
  ASSET_MEDIA_TYPE="${ASSET_MEDIA_TYPE:-text/csv}"

  _phase4b_validate_content_kind_value "${ASSET_CONTENT_KIND}"
  _phase4b_validate_extension_value "${ASSET_EXTENSION}"
  _phase4b_validate_kind_extension_pair "${ASSET_CONTENT_KIND}" "${ASSET_EXTENSION}"

  export ASSET_CONTENT_KIND ASSET_EXTENSION ASSET_MEDIA_TYPE
}

_phase4b_skip_placeholder() {
  local reason="$1"
  mkdir -p "${PHASE4B_DIR}"
  cat > "${PHASE4B_DIR}/00_status.txt" <<EOF
status=skipped
reason=${reason}
transfer_id=${TRANSFER_ID}
asset_id=${ASSET_ID}
EOF

  lib_write_summary "4b" storage_fetch skipped \
    "$(jq -nc \
      --arg status "skipped" \
      --arg reason "${reason}" \
      --arg transfer_id "${TRANSFER_ID}" \
      --arg asset_id "${ASSET_ID}" \
      --arg artifact "phase4b/00_status.txt" \
      '{status: $status, reason: $reason, transfer_id: $transfer_id, asset_id: $asset_id, artifact: $artifact}')"

  lib_set_phase_status "4b" skipped
  trap - ERR
  lib_log INFO "Fase 4b skipped — ${reason} (PHASE4B_ALLOW_SKIP=1, exit 0)"
  exit 0
}

_phase4b_resolve_state_file() {
  local sensitive="${PHASE3B_DIR}/21_transfer_final_state.sensitive.json"
  local legacy="${PHASE3B_DIR}/21_transfer_final_state.json"

  if [[ -f "${sensitive}" ]]; then
    printf '%s' "${sensitive}"
    return 0
  fi

  if [[ -f "${legacy}" ]]; then
    lib_log WARN "Usando 21_transfer_final_state.json legacy/unredacted (sin .sensitive.json)"
    printf '%s' "${legacy}"
    return 0
  fi

  lib_die "No existe ${sensitive} ni ${legacy} (¿phase3b OK?)"
}

_phase4b_extract_s3_credentials() {
  local state_file="$1"

  ENDPOINT="$(jq -r '.dataDestination.endpointOverride // empty' "${state_file}")"
  BUCKET="$(jq -r '.dataDestination.bucketName // empty' "${state_file}")"
  ACCESS_KEY="$(jq -r '.dataDestination.accessKeyId // empty' "${state_file}")"
  SECRET_KEY="$(jq -r '.dataDestination.secretAccessKey // empty' "${state_file}")"
  OBJECT_KEY="${STORE_FOLDER}/${UPLOAD_FILE_NAME}"
}

_phase4b_validate_credentials() {
  local missing=()

  [[ -n "${ENDPOINT}" ]] || missing+=("endpointOverride")
  [[ -n "${BUCKET}" ]] || missing+=("bucketName")
  [[ -n "${ACCESS_KEY}" ]] || missing+=("accessKeyId")
  [[ -n "${SECRET_KEY}" ]] || missing+=("secretAccessKey")
  [[ -n "${STORE_FOLDER:-}" ]] || missing+=("STORE_FOLDER")
  [[ -n "${UPLOAD_FILE_NAME:-}" ]] || missing+=("UPLOAD_FILE_NAME")

  if ((${#missing[@]} > 0)); then
    if [[ "${PHASE4B_ALLOW_SKIP:-}" == "1" ]]; then
      _phase4b_skip_placeholder "Credenciales S3 incompletas: ${missing[*]}"
    fi
    lib_die "Credenciales S3 incompletas en state file (faltan: ${missing[*]})"
  fi
}

_phase4b_mc_ls_diagnostic() {
  local ls_file="${PHASE4B_DIR}/10_consumer_storage_ls.txt"
  set +e
  mc --config-dir "${MC_CONFIG_DIR}" ls "consumer-b2/${BUCKET}/${STORE_FOLDER}/" > "${ls_file}" 2>&1
  set -e
  lib_log ERROR "Diagnóstico guardado en phase4b/10_consumer_storage_ls.txt"
}

_phase4b_write_manifest() {
  local dest="$1"
  local tmp="${dest}.$$"

  jq -n \
    --arg suffix "${SUFFIX}" \
    --arg asset_id "${ASSET_ID}" \
    --arg storage_mode "${STORAGE_MODE:-inesdatastore}" \
    --arg transfer_type "${TRANSFER_TYPE:-AmazonS3-PUSH}" \
    --arg transfer_id "${TRANSFER_ID}" \
    --arg consumer_transfer_state "${CONSUMER_TRANSFER_STATE:-}" \
    --arg content_kind "${ASSET_CONTENT_KIND}" \
    --arg extension "${ASSET_EXTENSION}" \
    --arg media_type "${ASSET_MEDIA_TYPE}" \
    --arg source "consumer_minio" \
    --arg endpoint "${ENDPOINT}" \
    --arg bucket "${BUCKET}" \
    --arg object_key "${OBJECT_KEY}" \
    --arg download_file "downloads/assets/${SAFE_ASSET_ID}/${SUFFIX}.${ASSET_EXTENSION}" \
    --arg latest_file "downloads/assets/${SAFE_ASSET_ID}/latest.${ASSET_EXTENSION}" \
    --argjson bytes "${FILE_BYTES}" \
    --arg sha256 "${FILE_SHA256}" \
    --arg created_at "$(lib_now_iso)" \
    --arg copy_action "${COPY_ACTION}" \
    '{
      suffix: $suffix,
      asset_id: $asset_id,
      storage_mode: $storage_mode,
      transfer_type: $transfer_type,
      transfer_id: $transfer_id,
      consumer_transfer_state: $consumer_transfer_state,
      content_kind: $content_kind,
      extension: $extension,
      media_type: $media_type,
      source: $source,
      endpoint: $endpoint,
      bucket: $bucket,
      object_key: $object_key,
      download_file: $download_file,
      latest_file: $latest_file,
      bytes: $bytes,
      sha256: $sha256,
      created_at: $created_at,
      copy_action: $copy_action
    }' > "${tmp}"

  mv "${tmp}" "${dest}"
}

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

PHASE4B_STEP="init"
api_find_root

if [[ ! -f "$(lib_phase_env_path 3b)" ]]; then
  lib_die "Ejecuta primero phase3b_inesdata_transfer.sh"
fi
# shellcheck source=/dev/null
source "$(lib_phase_env_path 3b)"

lib_load_env
lib_require_cmds
_phase4b_require_sha256
lib_require_vars SUFFIX ASSET_ID TRANSFER_ID STORE_FOLDER UPLOAD_FILE_NAME
[[ "${STORAGE_MODE:-}" == "inesdatastore" ]] \
  || lib_die "STORAGE_MODE debe ser inesdatastore (recibido: ${STORAGE_MODE:-<vacío>})"
_phase4b_apply_asset_content_defaults
lib_init_run_dirs
lib_init_summary

mkdir -p "${PHASE4B_DIR}"
DOWNLOADS_DIR="${API_ROOT}/downloads"
mkdir -p "${DOWNLOADS_DIR}"

PHASE4B_STEP="validate"
summary_file="${RUN_DIR}/summary.json"
[[ -f "${summary_file}" ]] \
  || lib_die "No existe ${summary_file}"
jq -e '.phases.phase3b.status == "ok"' "${summary_file}" >/dev/null \
  || lib_die "summary.json: phases.phase3b.status != ok"

PHASE4B_STEP="resolve_credentials"
STATE_FILE="$(_phase4b_resolve_state_file)"
_phase4b_extract_s3_credentials "${STATE_FILE}"
_phase4b_validate_credentials

SAFE_ASSET_ID="$(_phase4b_sanitize_asset_id "${ASSET_ID}")"
ASSET_DOWNLOAD_DIR="${DOWNLOADS_DIR}/assets/${SAFE_ASSET_ID}"
MANIFEST_DOWNLOAD_DIR="${DOWNLOADS_DIR}/manifests/${SAFE_ASSET_ID}"
mkdir -p "${ASSET_DOWNLOAD_DIR}" "${MANIFEST_DOWNLOAD_DIR}"

DOWNLOAD_FILE="${ASSET_DOWNLOAD_DIR}/${SUFFIX}.${ASSET_EXTENSION}"
LATEST_FILE="${ASSET_DOWNLOAD_DIR}/latest.${ASSET_EXTENSION}"
MANIFEST_FILE="${MANIFEST_DOWNLOAD_DIR}/${SUFFIX}.manifest.json"
LATEST_MANIFEST="${MANIFEST_DOWNLOAD_DIR}/latest.manifest.json"

# ---------------------------------------------------------------------------
# Descarga con mc (config temporal)
# ---------------------------------------------------------------------------

PHASE4B_STEP="storage_fetch"
_phase4b_require_mc

MC_CONFIG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/phase4b_mc.XXXXXX")"

if ! mc --config-dir "${MC_CONFIG_DIR}" alias set consumer-b2 "${ENDPOINT}" "${ACCESS_KEY}" "${SECRET_KEY}" >/dev/null 2>&1; then
  lib_die "mc alias set falló (revisar endpoint/credenciales en state file)"
fi

if [[ -f "${DOWNLOAD_FILE}" ]]; then
  if mc --config-dir "${MC_CONFIG_DIR}" cp \
    "consumer-b2/${BUCKET}/${OBJECT_KEY}" "${DOWNLOAD_FILE}.tmp.$$" >/dev/null 2>&1; then
    NEW_SHA256="$(_phase4b_sha256_file "${DOWNLOAD_FILE}.tmp.$$")"
    EXISTING_SHA256="$(_phase4b_sha256_file "${DOWNLOAD_FILE}")"
    if [[ "${NEW_SHA256}" == "${EXISTING_SHA256}" ]]; then
      COPY_ACTION="already_exists_same_hash"
      rm -f "${DOWNLOAD_FILE}.tmp.$$"
      lib_log INFO "Destino ya existe con mismo SHA256; no se sobrescribe ${DOWNLOAD_FILE}"
    else
      if [[ "${DOWNLOAD_FORCE:-}" != "1" ]]; then
        rm -f "${DOWNLOAD_FILE}.tmp.$$"
        lib_die "Destino ${DOWNLOAD_FILE} existe con contenido distinto. Export DOWNLOAD_FORCE=1 para sobrescribir."
      fi
      COPY_ACTION="overwritten"
      mv "${DOWNLOAD_FILE}.tmp.$$" "${DOWNLOAD_FILE}"
    fi
  else
    rm -f "${DOWNLOAD_FILE}.tmp.$$"
    _phase4b_mc_ls_diagnostic
    lib_die "mc cp falló para consumer-b2/${BUCKET}/${OBJECT_KEY}"
  fi
else
  if mc --config-dir "${MC_CONFIG_DIR}" cp \
    "consumer-b2/${BUCKET}/${OBJECT_KEY}" "${DOWNLOAD_FILE}" >/dev/null 2>&1; then
    COPY_ACTION="created"
  else
    _phase4b_mc_ls_diagnostic
    lib_die "mc cp falló para consumer-b2/${BUCKET}/${OBJECT_KEY}"
  fi
fi

# ---------------------------------------------------------------------------
# Validaciones post-descarga
# ---------------------------------------------------------------------------

PHASE4B_STEP="validate_download"
[[ -f "${DOWNLOAD_FILE}" ]] || lib_die "Descarga no creada: ${DOWNLOAD_FILE}"

FILE_BYTES="$(_phase4b_file_bytes "${DOWNLOAD_FILE}")"
if (( FILE_BYTES == 0 )) && [[ "${ALLOW_EMPTY_DOWNLOAD:-}" != "1" ]]; then
  lib_die "${DOWNLOAD_FILE} está vacío (export ALLOW_EMPTY_DOWNLOAD=1 para permitir)"
fi

if [[ "${ASSET_CONTENT_KIND}" == "json" ]]; then
  jq empty "${DOWNLOAD_FILE}" \
    || lib_die "${DOWNLOAD_FILE} no es JSON válido"
fi

FILE_SHA256="$(_phase4b_sha256_file "${DOWNLOAD_FILE}")"
cp "${DOWNLOAD_FILE}" "${LATEST_FILE}"

# ---------------------------------------------------------------------------
# Manifests
# ---------------------------------------------------------------------------

PHASE4B_STEP="write_manifest"
_phase4b_write_manifest "${MANIFEST_FILE}"
_phase4b_write_manifest "${LATEST_MANIFEST}"
_phase4b_write_manifest "${PHASE4B_DIR}/download_manifest.json"

# ---------------------------------------------------------------------------
# Cierre
# ---------------------------------------------------------------------------

PHASE4B_STEP="export_summary"
lib_write_summary "4b" storage_fetch ok \
  "$(jq -nc \
    --arg download_file "downloads/assets/${SAFE_ASSET_ID}/${SUFFIX}.${ASSET_EXTENSION}" \
    --arg latest_file "downloads/assets/${SAFE_ASSET_ID}/latest.${ASSET_EXTENSION}" \
    --arg manifest_file "downloads/manifests/${SAFE_ASSET_ID}/${SUFFIX}.manifest.json" \
    --argjson bytes "${FILE_BYTES}" \
    --arg sha256 "${FILE_SHA256}" \
    --arg source "consumer_minio" \
    --arg copy_action "${COPY_ACTION}" \
    '{
      download_file: $download_file,
      latest_file: $latest_file,
      manifest_file: $manifest_file,
      bytes: $bytes,
      sha256: $sha256,
      source: $source,
      copy_action: $copy_action
    }')"

lib_set_phase_status "4b" ok

trap - ERR
lib_log INFO "Fase 4b OK — latest=downloads/assets/${SAFE_ASSET_ID}/latest.${ASSET_EXTENSION} sha256=${FILE_SHA256}"
