#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-data/real/consumo/responses/sparql_format_tests}"
mkdir -p "${OUT_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
cd "${REPO_ROOT}"

scripts=(
  "data/real/consumo/sparql/curl_sparql_limit10_no_accept.sh"
  "data/real/consumo/sparql/curl_sparql_limit10_format_mime.sh"
  "data/real/consumo/sparql/curl_sparql_limit10_format_json.sh"
  "data/real/consumo/sparql/curl_sparql_limit10_output_json.sh"
)

declare -A variant_ok=()

for script in "${scripts[@]}"; do
  echo "== Ejecutando ${script} =="
  OUT_DIR="${OUT_DIR}" bash "${REPO_ROOT}/${script}" || true
done

echo
echo "== Validación de respuestas =="

_check_variant() {
  local label="$1"
  local f="$2"
  local ok=0 bindings=0

  echo
  echo "## ${label} — ${f}"
  if [[ ! -f "${f}" ]]; then
    echo "NOT_JSON ${label} (file missing)"
    variant_ok["${label}"]=0
    return
  fi
  file "${f}" || true
  head -c 250 "${f}" || true
  echo
  if jq empty "${f}" >/dev/null 2>&1; then
    echo "JSON_OK ${f}"
    jq 'type, keys' "${f}"
    if jq -e 'has("head") and has("results")' "${f}" >/dev/null 2>&1; then
      bindings="$(jq '.results.bindings | length' "${f}")"
      jq '.head.vars, (.results.bindings | length)' "${f}" 2>/dev/null || true
      if [[ "${bindings}" == "10" ]]; then
        ok=1
        echo "PASS ${label}: head/results OK, bindings=${bindings}"
      else
        echo "FAIL ${label}: bindings=${bindings} (expected 10)"
      fi
    else
      echo "FAIL ${label}: missing head/results keys"
    fi
  else
    echo "NOT_JSON ${label}"
  fi
  variant_ok["${label}"]="${ok}"
}

_check_variant "no_accept" "${OUT_DIR}/sparql_no_accept.response"
_check_variant "format_mime" "${OUT_DIR}/sparql_format_mime.response"
_check_variant "format_json" "${OUT_DIR}/sparql_format_json.response"
_check_variant "output_json" "${OUT_DIR}/sparql_output_json.response"

echo
echo "== Resumen =="
for label in no_accept format_mime format_json output_json; do
  if [[ "${variant_ok[${label}]:-0}" == "1" ]]; then
    echo "${label}: JSON"
  else
    echo "${label}: NOT_JSON"
  fi
done

winner="none"
for label in format_mime format_json output_json no_accept; do
  if [[ "${variant_ok[${label}]:-0}" == "1" ]]; then
    winner="${label}"
    break
  fi
done
echo "winner: ${winner}"
