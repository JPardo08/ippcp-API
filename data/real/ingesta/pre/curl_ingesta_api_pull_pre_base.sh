#!/usr/bin/env bash
set -euo pipefail
[[ $- != *x* ]] || set +x

OUT_DIR="${OUT_DIR:-data/real/ingesta/responses/pre}"
mkdir -p "${OUT_DIR}"

BODY_FILE="${OUT_DIR}/ingesta_api_pull_pre_base.json"
HEADERS_FILE="${OUT_DIR}/ingesta_api_pull_pre_base.headers.txt"
HTTP_FILE="${OUT_DIR}/ingesta_api_pull_pre_base.http"

validate_response() {
  local http_status
  http_status="$(tr -d '\n\r' < "${HTTP_FILE}")"

  if [[ "${http_status}" != "200" ]]; then
    echo "Respuesta inválida: HTTP status ${http_status}; esperado 200. Body: ${BODY_FILE}" >&2
    return 1
  fi

  if [[ ! -s "${BODY_FILE}" ]]; then
    echo "Respuesta inválida: body vacío en ${BODY_FILE}" >&2
    return 1
  fi

  if ! jq empty "${BODY_FILE}" >/dev/null 2>&1; then
    echo "Respuesta inválida: body no parsea como JSON en ${BODY_FILE}" >&2
    return 1
  fi
}

command -v jq >/dev/null 2>&1 || {
  echo "jq no encontrado en PATH; no se puede validar JSON." >&2
  exit 1
}

: "${INGESTA_API_KEY:?Falta INGESTA_API_KEY; carga data/real/ingesta/auth/ingesta_api_key.env}"
: "${INGESTA_API_PROVIDER_ID:?Falta INGESTA_API_PROVIDER_ID; carga data/real/ingesta/auth/ingesta_api_key.env}"

if [[ ! "${INGESTA_API_PROVIDER_ID}" =~ ^[0-9]+$ ]]; then
  echo "INGESTA_API_PROVIDER_ID debe ser numérico; no usar UUID de Keycloak." >&2
  exit 1
fi

if [[ "${INGESTA_API_EXTRA_HEADER:-}" =~ ^[Xx]-[Pp]rovider-[Ii]d: ]]; then
  echo "No definir X-Provider-Id en INGESTA_API_EXTRA_HEADER si INGESTA_API_PROVIDER_ID está definido." >&2
  exit 1
fi

if [[ "${INGESTA_API_EXTRA_HEADER:-}" =~ ^[Xx]-[Aa]pi-[Kk]ey: ]]; then
  echo "No definir X-Api-Key en INGESTA_API_EXTRA_HEADER; usa INGESTA_API_KEY." >&2
  exit 1
fi

curl_args=(
  -sS -L --get
  "https://urbanismo.geoslab.com/servicios/ippcp-ingesta/api/intake" \
  -H "Accept: application/json" \
  -H "X-Api-Key: ${INGESTA_API_KEY}" \
  -H "X-Provider-Id: ${INGESTA_API_PROVIDER_ID}" \
  -D "${HEADERS_FILE}" \
  -w "%{http_code}\n" \
  -o "${BODY_FILE}"
)

if [[ -n "${INGESTA_API_EXTRA_HEADER:-}" ]]; then
  curl_args+=(-H "${INGESTA_API_EXTRA_HEADER}")
fi

curl "${curl_args[@]}" > "${HTTP_FILE}"

echo "Ingesta API Pull PRE base guardado en ${BODY_FILE}"
echo "Headers guardados en ${HEADERS_FILE}"
echo "HTTP status guardado en ${HTTP_FILE}"
echo "HTTP status final: $(tr -d '\n\r' < "${HTTP_FILE}")"
validate_response
echo "Validación OK: HTTP 200, body no vacío y JSON válido."
