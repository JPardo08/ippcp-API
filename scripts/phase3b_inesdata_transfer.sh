#!/usr/bin/env bash
# Historical T1 B2/CSV reproducibility path; not current T4 ingestion.
# phase3b_inesdata_transfer.sh — Fase B2: transfer AmazonS3-PUSH → InesDataStore (consumer).
#
# No usa EDR ni HttpData-PULL. Prerrequisito: phase2 OK + phase1_env.sh con STORAGE_MODE=inesdatastore.
#
# Uso:
#   source runtime/env/latest/phase2_env.sh
#   /opt/homebrew/bin/bash scripts/phase3b_inesdata_transfer.sh

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_common.sh
source "${_SCRIPT_DIR}/lib_common.sh"

PHASE3B_STEP="init"
FINAL_STATE=""
STATE=""
TRANSFER_TYPE="AmazonS3-PUSH"

_phase3b_on_err() {
  local rc=$?
  if [[ -n "${RUN_DIR:-}" && -d "${RUN_DIR}" ]]; then
    lib_write_summary "3b" "${PHASE3B_STEP}" fail "{\"exit_code\":${rc}}" 2>/dev/null || true
    lib_set_phase_status "3b" fail 2>/dev/null || true
  fi
  exit "${rc}"
}
trap _phase3b_on_err ERR

_phase3b_write_json() {
  local dest="$1"
  local tmp="${dest}.$$"
  cat > "${tmp}"
  mv "${tmp}" "${dest}"
}

_phase3b_transfer_state() {
  jq -r '.state // ."edc:state" // empty' 2>/dev/null
}

_phase3b_state_acceptable() {
  case "${1}" in
    STARTED|COMPLETED) return 0 ;;
    *) return 1 ;;
  esac
}

_phase3b_state_pollable() {
  case "${1}" in
    INITIAL|REQUESTED|STARTING|STARTED|COMPLETING) return 0 ;;
    *) return 1 ;;
  esac
}

_phase3b_state_failed() {
  case "${1}" in
    TERMINATED|FAILED|ERROR|DEPROVISIONED|DEPROVISIONING) return 0 ;;
    *) return 1 ;;
  esac
}

_phase3b_redact_json_file() {
  local json_file="$1"
  _phase3b_redact_transfer_response "${json_file}" "${json_file}"
}

_phase3b_finalize_transfer_state() {
  local poll_base="$1"
  local poll_json="${poll_base}.json"
  local sensitive="${PHASE3B_DIR}/21_transfer_final_state.sensitive.json"

  cp "${poll_json}" "${sensitive}"
  chmod 600 "${sensitive}"

  _phase3b_redact_json_file "${poll_json}"
  cp "${poll_json}" "${PHASE3B_DIR}/21_transfer_final_state.json"
  cp "${poll_base}.http" "${PHASE3B_DIR}/21_transfer_final_state.http"
}

_phase3b_poll_transfer_until_ready() {
  local start_i="${1:-1}"
  local i poll_n last_poll_base=""

  for i in $(seq "${start_i}" 20); do
    poll_n="$(printf '%02d' "${i}")"
    last_poll_base="${PHASE3B_DIR}/20_transfer_state_${poll_n}"

    lib_curl_json "${last_poll_base}" \
      -X GET "${CONSUMER_BASE}/management/v3/transferprocesses/${TRANSFER_ID}" \
      -H "Authorization: Bearer ${CONSUMER_JWT}"

    STATE="$(_phase3b_transfer_state < "${last_poll_base}.json")"
    STATE="${STATE^^}"
    lib_log INFO "[transfer 3b ${i}] state=${STATE:-<none>}"

    if _phase3b_state_acceptable "${STATE}"; then
      FINAL_STATE="${STATE}"
      _phase3b_finalize_transfer_state "${last_poll_base}"
      return 0
    fi

    if _phase3b_state_failed "${STATE}"; then
      _phase3b_redact_json_file "${last_poll_base}.json"
      lib_die "Transfer ${STATE} (revisar phase3b/20_transfer_state_${poll_n}.json)"
    fi

    _phase3b_redact_json_file "${last_poll_base}.json"
    [[ "${i}" -lt 20 ]] && sleep 3
  done

  lib_die "Timeout: transfer no alcanzó STARTED/COMPLETED (último: ${STATE:-desconocido})"
}

_phase3b_inspect_catalog_distributions() {
  local dataset_file="$1"
  local out_file="${PHASE3B_DIR}/catalog_distributions_summary.json"
  local tmp="${out_file}.$$"
  local has_s3_push=false

  jq '
    (
      ."dcat:distribution"
      // ."http://www.w3.org/ns/dcat#distribution"
      // []
    )
    | if type == "array" then . else [.] end
    | map(
        ."dct:format"."@id"
        // ."http://purl.org/dc/terms/format"."@id"
        // ."dct:format"
        // .
      )
  ' "${dataset_file}" > "${tmp}" 2>/dev/null || echo '[]' > "${tmp}"

  if jq -e 'map(tostring) | any(test("AmazonS3-PUSH"; "i"))' "${tmp}" >/dev/null 2>&1; then
    has_s3_push=true
  fi

  jq -n \
    --argjson formats "$(cat "${tmp}")" \
    --argjson has_amazon_s3_push "$([[ "${has_s3_push}" == true ]] && echo true || echo false)" \
    --arg note "Inspección informativa; no bloquea transfer AmazonS3-PUSH" \
    '{formats: $formats, has_amazon_s3_push: $has_amazon_s3_push, note: $note}' > "${out_file}"
  rm -f "${tmp}"

  if [[ "${has_s3_push}" == true ]]; then
    lib_log INFO "Catálogo Fase 2 anuncia AmazonS3-PUSH para ${ASSET_ID}"
  else
    lib_log INFO "Catálogo Fase 2 no muestra AmazonS3-PUSH explícito; se intentará transfer igualmente"
  fi
}

_phase3b_redact_transfer_response() {
  local src="$1"
  local dest="$2"
  local tmp="${dest}.$$"

  jq '
    walk(
      if type == "object" then
        with_entries(
          if (.key | test("secret|password|accessKey|secretKey|credential"; "i")) then
            .value = "<redacted>"
          else . end
        )
      else . end
    )
  ' "${src}" > "${tmp}" 2>/dev/null || cp "${src}" "${tmp}"
  mv "${tmp}" "${dest}"
}

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

PHASE3B_STEP="init"
api_find_root

if [[ -z "${SUFFIX:-}" || -z "${ASSET_ID:-}" ]] || [[ -z "${AGREEMENT_ID:-}" ]]; then
  if [[ ! -f "$(lib_phase_env_path 2)" ]]; then
    lib_die "Ejecuta primero phase2_consumer_negotiate.sh"
  fi
  # shellcheck source=/dev/null
  source "$(lib_phase_env_path 2)"
fi

if [[ -f "$(lib_phase_env_path 1)" ]]; then
  # shellcheck source=/dev/null
  source "$(lib_phase_env_path 1)"
fi

[[ "${STORAGE_MODE:-}" == "inesdatastore" ]] \
  || lib_die "STORAGE_MODE debe ser inesdatastore (recibido: ${STORAGE_MODE:-<vacío>}). ¿Ejecutaste phase1b?"

lib_load_env
lib_require_cmds
lib_require_vars_group LIB_VARS_DATASPACE
lib_require_vars_group LIB_VARS_PROVIDER
lib_require_vars_group LIB_VARS_CONSUMER
lib_require_vars_group LIB_VARS_PHASE2
lib_derive_phase1_ids
lib_init_run_dirs
lib_init_summary

PHASE3B_STEP="jwt_renew"
lib_renew_jwt consumer
lib_jwt_check_console consumer

PHASE3B_STEP="write_context"
{
  printf 'Fecha: %s\n' "$(date)"
  printf 'SUFFIX=%s\n' "${SUFFIX}"
  printf 'STORAGE_MODE=%s\n' "${STORAGE_MODE}"
  printf 'ASSET_ID=%s\n' "${ASSET_ID}"
  printf 'AGREEMENT_ID=%s\n' "${AGREEMENT_ID}"
  printf 'TRANSFER_TYPE=%s\n' "${TRANSFER_TYPE}"
  printf 'ASSET_EXTENSION=%s\n' "${ASSET_EXTENSION:-csv}"
} > "${PHASE3B_DIR}/00_context.txt"

# ---------------------------------------------------------------------------
# Inspección catálogo (soft — no falla si falta AmazonS3-PUSH)
# ---------------------------------------------------------------------------

PHASE3B_STEP="catalog_distributions"
_phase2_dataset="${PHASE2_DIR}/selected_remote_catalog_dataset.json"
[[ -f "${_phase2_dataset}" ]] \
  || lib_die "No existe ${_phase2_dataset} (¿phase2 OK?)"
_phase3b_inspect_catalog_distributions "${_phase2_dataset}"
lib_write_summary "3b" catalog_distributions ok \
  '{"artifact":"phase3b/catalog_distributions_summary.json","note":"inspección informativa"}'

# ---------------------------------------------------------------------------
# Transfer AmazonS3-PUSH
# ---------------------------------------------------------------------------

PHASE3B_STEP="transfer_started"
transfer_request="${PHASE3B_DIR}/10_transfer_request.json"
_phase3b_write_json "${transfer_request}" <<EOF
{
  "@context": { "@vocab": "https://w3id.org/edc/v0.0.1/ns/" },
  "@type": "TransferRequest",
  "assetId": "${ASSET_ID}",
  "contractId": "${AGREEMENT_ID}",
  "counterPartyAddress": "${PROVIDER_PROTOCOL}",
  "protocol": "dataspace-protocol-http",
  "transferType": "AmazonS3-PUSH",
  "dataDestination": {
    "type": "InesDataStore"
  }
}
EOF

lib_curl_json "${PHASE3B_DIR}/10_transfer_response" \
  -X POST "${CONSUMER_BASE}/management/v3/inesdatatransferprocesses" \
  -H "Authorization: Bearer ${CONSUMER_JWT}" \
  -H "Content-Type: application/json" \
  -d "@${transfer_request}"

TRANSFER_ID="$(jq -r '."@id" // .id // empty' "${PHASE3B_DIR}/10_transfer_response.json")"
[[ -n "${TRANSFER_ID}" ]] || lib_die "TRANSFER_ID vacío tras inesdatatransferprocesses"

_phase3b_redact_transfer_response \
  "${PHASE3B_DIR}/10_transfer_response.json" \
  "${PHASE3B_DIR}/10_transfer_response_redacted.json"

transfer_http="$(tr -d '\n\r' < "${PHASE3B_DIR}/10_transfer_response.http")"
lib_write_summary "3b" transfer_started ok \
  "$(jq -nc \
    --argjson http "${transfer_http}" \
    --arg transfer_id "${TRANSFER_ID}" \
    --arg transfer_type "${TRANSFER_TYPE}" \
    --arg artifact "phase3b/10_transfer_response" \
    '{http: $http, transfer_id: $transfer_id, transfer_type: $transfer_type, artifact: $artifact}')"

export TRANSFER_ID TRANSFER_TYPE

PHASE3B_STEP="transfer_final_state"
_phase3b_poll_transfer_until_ready 1
CONSUMER_TRANSFER_STATE="${FINAL_STATE}"
export CONSUMER_TRANSFER_STATE

lib_write_summary "3b" transfer_final_state ok \
  "$(jq -nc \
    --arg transfer_id "${TRANSFER_ID}" \
    --arg final_state "${FINAL_STATE}" \
    --arg transfer_type "${TRANSFER_TYPE}" \
    --arg artifact "phase3b/21_transfer_final_state" \
    '{transfer_id: $transfer_id, final_state: $final_state, transfer_type: $transfer_type, artifact: $artifact}')"

PHASE3B_STEP="export_env"
lib_export_phase_env 3b
lib_set_phase_status "3b" ok

trap - ERR
lib_log INFO "Fase 3b OK — SUFFIX=${SUFFIX} TRANSFER_ID=${TRANSFER_ID} STATE=${FINAL_STATE}"
