#!/usr/bin/env bash
# phase0_context_smoke.sh — Fase 0: contextualización y smoke test inicial (test3).
#
# Requisitos: Bash 4.3+, curl, jq (ver scripts/scripts_README.md).
#
# Nueva ejecución real:
#   Usar terminal limpia o ejecutar `unset SUFFIX` antes de lanzar el script,
#   para que lib_load_env genere un SUFFIX nuevo vía export_suffix.sh.
#
# Continuar una ejecución existente:
#   source runtime/env/latest/phase0_env.sh   # o phase1_env.sh / phase2_env.sh
#   /opt/homebrew/bin/bash scripts/phase0_context_smoke.sh
#
# Uso:
#   /opt/homebrew/bin/bash scripts/phase0_context_smoke.sh

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_common.sh
source "${_SCRIPT_DIR}/lib_common.sh"

readonly ASSETS_REQUEST_BODY='{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"offset":0,"limit":1,"filterExpression":[]}'

PHASE0_STEP="init"

_phase0_on_err() {
  local rc=$?
  if [[ -n "${RUN_DIR:-}" && -d "${RUN_DIR}" ]]; then
    lib_write_summary 0 "${PHASE0_STEP}" fail "{\"exit_code\":${rc}}" 2>/dev/null || true
    lib_set_phase_status 0 fail 2>/dev/null || true
  fi
  exit "${rc}"
}
trap _phase0_on_err ERR

# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

PHASE0_STEP="init"
api_find_root
lib_load_env
lib_require_cmds
lib_require_vars_group LIB_VARS_DATASPACE
lib_require_vars_group LIB_VARS_PROVIDER
lib_require_vars_group LIB_VARS_CONSUMER
lib_init_run_dirs
lib_init_summary

# ---------------------------------------------------------------------------
# JWT provider + consumer
# ---------------------------------------------------------------------------

PHASE0_STEP="jwt_renew"
lib_renew_jwt both
lib_jwt_check_console provider consumer

PHASE0_STEP="jwt_claims"
lib_jwt_claims_to_json provider "${PHASE0_DIR}/jwt_claims_provider.json"
lib_jwt_claims_to_json consumer "${PHASE0_DIR}/jwt_claims_consumer.json"

lib_write_summary 0 jwt_provider ok '{"artifact":"phase0/jwt_claims_provider.json"}'
lib_write_summary 0 jwt_consumer ok '{"artifact":"phase0/jwt_claims_consumer.json"}'

# ---------------------------------------------------------------------------
# Smoke: POST assets/request (Opción A — no exige array vacío)
# ---------------------------------------------------------------------------

PHASE0_STEP="provider_assets_smoke"
lib_curl_json "${PHASE0_DIR}/01_provider_assets_smoke" \
  -X POST "${PROVIDER_BASE}${ENDPOINTS[asset]}" \
  -H "Authorization: Bearer ${PROVIDER_JWT}" \
  -H "Content-Type: application/json" \
  -d "${ASSETS_REQUEST_BODY}"

PHASE0_STEP="consumer_assets_smoke"
lib_curl_json "${PHASE0_DIR}/02_consumer_assets_smoke" \
  -X POST "${CONSUMER_BASE}${ENDPOINTS[asset]}" \
  -H "Authorization: Bearer ${CONSUMER_JWT}" \
  -H "Content-Type: application/json" \
  -d "${ASSETS_REQUEST_BODY}"

provider_http="$(tr -d '\n' < "${PHASE0_DIR}/01_provider_assets_smoke.http")"
consumer_http="$(tr -d '\n' < "${PHASE0_DIR}/02_consumer_assets_smoke.http")"

provider_asset_count="$(jq 'length' "${PHASE0_DIR}/01_provider_assets_smoke.json")"
consumer_asset_count="$(jq 'length' "${PHASE0_DIR}/02_consumer_assets_smoke.json")"

lib_write_summary 0 provider_assets_smoke ok \
  "{\"http\":${provider_http},\"asset_count\":${provider_asset_count},\"artifact\":\"phase0/01_provider_assets_smoke\"}"
lib_write_summary 0 consumer_assets_smoke ok \
  "{\"http\":${consumer_http},\"asset_count\":${consumer_asset_count},\"artifact\":\"phase0/02_consumer_assets_smoke\"}"

# ---------------------------------------------------------------------------
# Contexto legible (declarado; no se comprueba SSH/VPN/etc.)
# ---------------------------------------------------------------------------

PHASE0_STEP="write_context"
context_file="${PHASE0_DIR}/00_context.txt"
context_tmp="${context_file}.$$"

{
  printf 'Fecha: %s\n' "$(date)"
  printf 'API_ROOT=%s\n' "${API_ROOT}"
  printf 'DS_NAME=%s\n' "${DS_NAME}"
  printf 'KEYCLOAK_URL=%s\n' "${KEYCLOAK_URL}"
  printf 'PROVIDER=%s\n' "${PROVIDER}"
  printf 'PROVIDER_BASE=%s\n' "${PROVIDER_BASE}"
  printf 'PROVIDER_PROTOCOL=%s\n' "${PROVIDER_PROTOCOL}"
  printf 'CONSUMER=%s\n' "${CONSUMER}"
  printf 'CONSUMER_BASE=%s\n' "${CONSUMER_BASE}"
  printf 'CONSUMER_PROTOCOL=%s\n' "${CONSUMER_PROTOCOL}"
  printf 'SUFFIX=%s\n' "${SUFFIX}"
  printf 'RUN_DIR=%s\n' "${RUN_DIR}"
  printf '\n'
  printf 'Provider HTTP: %s\n' "${provider_http}"
  printf 'Consumer HTTP: %s\n' "${consumer_http}"
  printf 'provider_asset_count: %s\n' "${provider_asset_count}"
  printf 'consumer_asset_count: %s\n' "${consumer_asset_count}"
  printf '\n'
  printf 'Contexto de ejecución declarado (no verificado automáticamente):\n'
  printf '  sin SSH\n'
  printf '  sin kubeconfig\n'
  printf '  sin port-forward\n'
  printf '  sin /etc/hosts\n'
  printf '  sin VPN\n'
} > "${context_tmp}"
mv "${context_tmp}" "${context_file}"

# ---------------------------------------------------------------------------
# Cierre
# ---------------------------------------------------------------------------

PHASE0_STEP="export_env"
lib_export_phase_env 0
lib_set_phase_status 0 ok

trap - ERR
lib_log INFO "Fase 0 OK — SUFFIX=${SUFFIX} RUN_DIR=${RUN_DIR}"
