#!/usr/bin/env bash
# phase4_save_download.sh — Fase 4: consumir EDR y materializar descarga local.
#
# Requisitos: Bash 4.3+, curl, jq, shasum u openssl (ver scripts/scripts_README.md).
#
# Prerrequisito: phase3 OK (phase3_env.sh o variables exportadas).
# Sobrescribir descarga existente con hash distinto: DOWNLOAD_FORCE=1
# Permitir body vacío: ALLOW_EMPTY_DOWNLOAD=1
#
# Uso:
#   source runtime/env/latest/phase3_env.sh
#   /opt/homebrew/bin/bash scripts/phase4_save_download.sh

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_common.sh
source "${_SCRIPT_DIR}/lib_common.sh"

PHASE4_STEP="init"
PHASE4_EDR_TMP_DIR=""
PHASE4_EDR_RAW_FILE=""
PHASE4_EDR_HTTP=""
PHASE4_EDR_SOURCE=""
PHASE4_EDR_AUTHORIZATION=""
PHASE4_EDR_AUTH_CODE=""
PHASE4_EDR_AUTH_KEY=""
PHASE4_EDR_AUTH_TYPE=""
PHASE4_AUTH_CANDIDATE_LABEL=""
PHASE4_DATA_RESPONSE_FILE=""
COPY_ACTION=""

declare -a PHASE4_AUTH_CANDIDATE_LABELS=()
declare -a PHASE4_AUTH_CANDIDATE_HEADERS=()

_phase4_cleanup() {
  if [[ -n "${PHASE4_EDR_TMP_DIR}" && -d "${PHASE4_EDR_TMP_DIR}" ]]; then
    rm -rf "${PHASE4_EDR_TMP_DIR}"
    PHASE4_EDR_TMP_DIR=""
  fi
}

_phase4_on_err() {
  local rc=$?
  _phase4_cleanup
  if [[ -n "${RUN_DIR:-}" && -d "${RUN_DIR}" ]]; then
    lib_write_summary 4 "${PHASE4_STEP}" fail "{\"exit_code\":${rc}}" 2>/dev/null || true
    lib_set_phase_status 4 fail 2>/dev/null || true
  fi
  exit "${rc}"
}
trap _phase4_on_err ERR
trap _phase4_cleanup EXIT

_phase4_id_is_set() {
  local value="${1:-}"
  [[ -n "${value}" && "${value}" != "null" ]]
}

_phase4_write_json() {
  local dest="$1"
  local tmp="${dest}.$$"
  cat > "${tmp}"
  mv "${tmp}" "${dest}"
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

_phase4_data_response_basename() {
  printf '40_data_response.%s' "${ASSET_EXTENSION}"
}

_phase4_edr_url_has_sensitive_params() {
  local value="${1:-}"
  local lower="${value,,}"

  [[ "${lower}" =~ [\?\#\&]([^=]*)(access_token|token|bearer|auth|code|credential)([^=]*)= ]]
}

_phase4_safe_edr_url() {
  if _phase4_edr_url_has_sensitive_params "${EDR_URL:-}"; then
    printf '%s' '<redacted-sensitive-edr-url>'
  else
    printf '%s' "${EDR_URL:-}"
  fi
}

_phase4_assert_no_sensitive_control_artifact() {
  local file="$1"
  [[ -f "${file}" ]] || return 0

  if awk '/Authorization|Bearer |access_token|INGESTA_API_BEARER_TOKEN|client_secret/ { found = 1; exit } END { exit found ? 0 : 1 }' "${file}"; then
    lib_die "Artefacto phase4 contiene material sensible o header Authorization: ${file}"
  fi

  if [[ "${file}" == *.json ]] && jq -e '
    . as $root
    | any(paths(scalars) as $p;
        (($p[-1] | tostring | ascii_downcase | endswith("header:x-api-key")))
        and (($root | getpath($p)) != "<redacted>"))
  ' "${file}" >/dev/null 2>&1; then
    lib_die "Artefacto phase4 contiene header:X-Api-Key sin <redacted>: ${file}"
  fi
}

_phase4_redact_edr_file() {
  local raw_file="$1"
  local redacted_file="$2"
  local tmp="${redacted_file}.$$"

  jq '
    def key_visible($k):
      ($k | ascii_downcase) as $kl
      | ($kl == "endpoint" or $kl == "endpointurl" or $kl == "edc:endpoint");
    def key_should_redact($k):
      key_visible($k) | not
      and (
        ($k | ascii_downcase | test("token"))
        or ($k | ascii_downcase | test("secret"))
        or ($k | ascii_downcase | test("authorization"))
        or ($k | ascii_downcase | test("auth"))
        or ($k | ascii_downcase | test("code"))
        or ($k | ascii_downcase | test("credential"))
      );
    def redact:
      if type == "object" then
        with_entries(
          if (.key | ascii_downcase | endswith("header:x-api-key")) then
            .value = "<redacted>"
          elif key_should_redact(.key) then
            .value = "***REDACTED***"
          elif (.value | type) == "object" or (.value | type) == "array" then
            .value |= redact
          else
            .
          end
        )
      elif type == "array" then
        map(redact)
      else
        .
      end;
    redact
  ' "${raw_file}" > "${tmp}"
  mv "${tmp}" "${redacted_file}"
}

_phase4_write_edr_keys_diagnostic() {
  local raw_file="$1"
  local keys_file="$2"
  local tmp="${keys_file}.$$"

  jq '
    def path_label($p):
      $p | map(if type == "number" then "[\(. | tostring)]" else . end) | join(".");
    def key_sensitive($k):
      ($k | ascii_downcase) as $kl
      | ($kl | test("auth"))
      or ($kl | test("token"))
      or ($kl | test("secret"))
      or ($kl | test("code"))
      or ($kl | test("key"))
      or ($kl | test("credential"));
    {
      top_level_keys: (if type == "object" then (keys | sort) else [] end),
      sensitive_key_paths: (
        [
          paths(scalars) as $p
          | ($p[-1] | tostring) as $k
          | select(key_sensitive($k))
          | path_label($p)
        ] | unique | sort
      )
    }
  ' "${raw_file}" > "${tmp}"
  mv "${tmp}" "${keys_file}"
}

_phase4_extract_edr_url() {
  jq -r '.endpoint // .endpointUrl // ."edc:endpoint" // empty' "$1"
}

_phase4_extract_auth_json() {
  local raw_file="$1"

  jq -c '
    def as_string:
      if . == null or . == "" then empty
      elif type == "string" then .
      elif type == "object" then
        (."@value" // .value // .token // .authorization // empty) | as_string
      else empty
      end;
    def key_is_authtype($k):
      ($k | ascii_downcase) == "authtype";
    def key_matches_authorization_token($k):
      key_is_authtype($k) | not
      and (
        ($k | ascii_downcase | test("authorization"))
        or (($k | ascii_downcase) == "token")
        or ($k | ascii_downcase | test("accesstoken"))
        or ($k | ascii_downcase | test("access_token"))
        or ($k | ascii_downcase | test("bearertoken"))
        or ($k | ascii_downcase | test("bearer_token"))
      );
    def key_matches_auth_code($k):
      key_is_authtype($k) | not
      and (
        ($k | ascii_downcase | test("authcode"))
        or ($k | ascii_downcase | test("auth_code"))
        or (($k | ascii_downcase) == "code")
      );
    def key_matches_auth_key($k):
      key_is_authtype($k) | not
      and (
        ($k | ascii_downcase | test("authkey"))
        or ($k | ascii_downcase | test("auth_key"))
        or (($k | ascii_downcase) == "header")
      );
    def find_authorization_recursive:
      [
        .. | objects | to_entries[]
        | select(key_matches_authorization_token(.key))
        | .value | as_string
        | select(. != "")
      ] | first // empty;
    def find_auth_code_recursive:
      [
        .. | objects | to_entries[]
        | select(key_matches_auth_code(.key))
        | .value | as_string
        | select(. != "")
      ] | first // empty;
    def find_auth_key_recursive:
      [
        .. | objects | to_entries[]
        | select(key_matches_auth_key(.key))
        | .value | as_string
        | select(. != "")
      ] | first // empty;
    def direct_authorization:
      (
        .authorization // .Authorization
        // ."edc:authorization"
        // ."https://w3id.org/edc/v0.0.1/ns/authorization"
        // .auth // .token // .accessToken // .access_token
        // .bearerToken // .bearer_token // .credential
        // (.credentials.authorization // .credentials.auth // empty)
        // (.properties.authorization // .properties.auth // .properties.token
           // .properties.accessToken // .properties.access_token // empty)
      ) | as_string;
    def direct_auth_code:
      (
        .authCode // ."edc:authCode"
        // ."https://w3id.org/edc/v0.0.1/ns/authCode"
        // .auth_code // .code
        // (.properties.authCode // .properties.auth_code // .properties.code // empty)
      ) | as_string;
    def direct_auth_key:
      (
        .authKey // ."edc:authKey"
        // ."https://w3id.org/edc/v0.0.1/ns/authKey"
        // .auth_key // .key // .header
        // (.properties.authKey // .properties.auth_key // .properties.key
           // .properties.header // empty)
      ) | as_string;
    {
      authorization: (direct_authorization // find_authorization_recursive // ""),
      authCode: (direct_auth_code // find_auth_code_recursive // ""),
      authKey: (direct_auth_key // find_auth_key_recursive // ""),
      authType: ((.authType // ."edc:authType" // ."https://w3id.org/edc/v0.0.1/ns/authType" // "") | if type == "string" then . else "" end)
    }
  ' "${raw_file}"
}

_phase4_load_edr_auth_fields() {
  local raw_file="$1"
  local auth_json

  auth_json="$(_phase4_extract_auth_json "${raw_file}")"
  PHASE4_EDR_AUTHORIZATION="$(jq -r '.authorization // empty' <<< "${auth_json}")"
  PHASE4_EDR_AUTH_CODE="$(jq -r '.authCode // empty' <<< "${auth_json}")"
  PHASE4_EDR_AUTH_KEY="$(jq -r '.authKey // empty' <<< "${auth_json}")"
  PHASE4_EDR_AUTH_TYPE="$(jq -r '.authType // empty' <<< "${auth_json}")"

  if _phase4_id_is_set "${PHASE4_EDR_AUTHORIZATION}" \
    || { _phase4_id_is_set "${PHASE4_EDR_AUTH_KEY}" && _phase4_id_is_set "${PHASE4_EDR_AUTH_CODE}"; }; then
    return 0
  fi

  lib_die "EDR DataAddress sin credenciales reconocibles. Revisar phase4/30_edr_dataaddress_redacted.json y phase4/30_edr_dataaddress_keys.json"
}

_phase4_authorization_has_bearer_prefix() {
  local value="${1:-}"
  [[ "${value}" =~ ^[Bb][Ee][Aa][Rr][Ee][Rr][[:space:]] ]]
}

_phase4_normalize_auth_type_prefix() {
  local auth_type="${1:-}"
  local lower="${auth_type,,}"
  case "${lower}" in
    bearer) printf 'Bearer' ;;
    *) printf '%s' "${auth_type}" ;;
  esac
}

_phase4_register_auth_candidate() {
  local label="$1"
  local header="$2"
  local existing

  for existing in "${PHASE4_AUTH_CANDIDATE_HEADERS[@]}"; do
    [[ "${existing}" == "${header}" ]] && return 0
  done

  PHASE4_AUTH_CANDIDATE_LABELS+=("${label}")
  PHASE4_AUTH_CANDIDATE_HEADERS+=("${header}")
}

_phase4_build_auth_candidates() {
  PHASE4_AUTH_CANDIDATE_LABELS=()
  PHASE4_AUTH_CANDIDATE_HEADERS=()

  if _phase4_id_is_set "${PHASE4_EDR_AUTH_KEY}" && _phase4_id_is_set "${PHASE4_EDR_AUTH_CODE}"; then
    _phase4_register_auth_candidate "authkey_authcode" "${PHASE4_EDR_AUTH_KEY}: ${PHASE4_EDR_AUTH_CODE}"
  fi

  if _phase4_id_is_set "${PHASE4_EDR_AUTHORIZATION}"; then
    if _phase4_authorization_has_bearer_prefix "${PHASE4_EDR_AUTHORIZATION}"; then
      _phase4_register_auth_candidate "authorization_as_is" "Authorization: ${PHASE4_EDR_AUTHORIZATION}"
    fi

    _phase4_register_auth_candidate "authorization_raw" "Authorization: ${PHASE4_EDR_AUTHORIZATION}"

    if ! _phase4_authorization_has_bearer_prefix "${PHASE4_EDR_AUTHORIZATION}"; then
      _phase4_register_auth_candidate "authorization_bearer" "Authorization: Bearer ${PHASE4_EDR_AUTHORIZATION}"

      if _phase4_id_is_set "${PHASE4_EDR_AUTH_TYPE}"; then
        _phase4_register_auth_candidate "authorization_authtype" \
          "Authorization: $(_phase4_normalize_auth_type_prefix "${PHASE4_EDR_AUTH_TYPE}") ${PHASE4_EDR_AUTHORIZATION}"
      fi
    fi
  fi

  (( ${#PHASE4_AUTH_CANDIDATE_LABELS[@]} > 0 )) \
    || lib_die "No hay candidatos de autenticación EDR tras extraer credenciales"
}

_phase4_header_is_authorization() {
  local header="${1:-}"
  [[ "${header}" =~ ^[Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Aa][Tt][Ii][Oo][Nn]: ]]
}

_phase4_ensure_edr_tmp_dir() {
  if [[ -z "${PHASE4_EDR_TMP_DIR}" || ! -d "${PHASE4_EDR_TMP_DIR}" ]]; then
    PHASE4_EDR_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/phase4_edr.XXXXXX")"
  fi
}

_phase4_select_edr_entry() {
  local raw_file="$1"
  local selected_file="$2"

  jq -e \
    --arg transfer_id "${TRANSFER_ID}" \
    --arg asset_id "${ASSET_ID}" \
    --arg agreement_id "${AGREEMENT_ID}" \
    '
      def as_array:
        if type == "array" then . else if . == null then [] else [.] end end;
      def entry_transfer_id:
        .transferProcessId // ."edc:transferProcessId" // empty;
      def entry_asset_id:
        .assetId // ."edc:assetId" // empty;
      def entry_agreement_id:
        .agreementId // .contractAgreementId // ."edc:contractAgreementId"
        // ."edc:agreementId" // empty;
      def entry_data_address:
        if (.dataAddress // null) != null then .dataAddress else . end;
      . as $root
      | ($root | as_array)
      | map(select(
          (entry_transfer_id == $transfer_id)
          or (
            (entry_asset_id == $asset_id)
            and (entry_agreement_id == $agreement_id)
          )
        ))
      | .[0] // empty
      | if . == null or . == {} then empty else entry_data_address end
    ' "${raw_file}" > "${selected_file}"
}

_phase4_finalize_edr() {
  local raw_file="$1"

  EDR_URL="$(_phase4_extract_edr_url "${raw_file}")"
  [[ -n "${EDR_URL}" && "${EDR_URL}" != "null" ]] \
    || lib_die "EDR_URL vacío tras resolver DataAddress"

  _phase4_redact_edr_file "${raw_file}" "${PHASE4_DIR}/30_edr_dataaddress_redacted.json"
  _phase4_write_edr_keys_diagnostic "${raw_file}" "${PHASE4_DIR}/30_edr_dataaddress_keys.json"
  _phase4_load_edr_auth_fields "${raw_file}"
}

_phase4_poll_edr_direct() {
  local i poll_n http_code curl_exit raw_base url

  _phase4_ensure_edr_tmp_dir
  PHASE4_EDR_RAW_FILE=""
  PHASE4_EDR_HTTP=""

  for i in $(seq 1 20); do
    poll_n="$(printf '%02d' "${i}")"
    raw_base="${PHASE4_EDR_TMP_DIR}/dataaddress_${poll_n}"
    rm -f "${raw_base}.json"

    set +e
    http_code="$(
      curl -sS -o "${raw_base}.json" -w '%{http_code}' \
        -X GET "${CONSUMER_BASE}/management/v3/edrs/${TRANSFER_ID}/dataaddress" \
        -H "Authorization: Bearer ${CONSUMER_JWT}"
    )"
    curl_exit=$?
    set -e

    printf '%s\n' "${http_code}" > "${PHASE4_DIR}/30_edr_direct_${poll_n}.http"
    lib_log INFO "[phase4 edr-direct ${i}] HTTP=${http_code} curl_exit=${curl_exit}"

    if (( curl_exit != 0 )); then
      [[ "${i}" -lt 20 ]] && sleep 3
      continue
    fi

    if [[ "${http_code}" =~ ^2[0-9]{2}$ ]] \
      && [[ -s "${raw_base}.json" ]] \
      && jq empty "${raw_base}.json" 2>/dev/null; then
      url="$(_phase4_extract_edr_url "${raw_base}.json")"
      if _phase4_id_is_set "${url}"; then
        PHASE4_EDR_RAW_FILE="${raw_base}.json"
        PHASE4_EDR_HTTP="${http_code}"
        return 0
      fi
    fi

    [[ "${i}" -lt 20 ]] && sleep 3
  done

  return 1
}

_phase4_fetch_edr_fallback() {
  local req_file raw_base http_code curl_exit selected_file url

  _phase4_ensure_edr_tmp_dir
  req_file="${PHASE4_DIR}/31_edrs_request_body.json"
  raw_base="${PHASE4_EDR_TMP_DIR}/edrs_request"
  selected_file="${PHASE4_EDR_TMP_DIR}/selected_dataaddress.json"

  _phase4_write_json "${req_file}" <<'EOF'
{
  "@context": { "@vocab": "https://w3id.org/edc/v0.0.1/ns/" },
  "offset": 0,
  "limit": 50,
  "filterExpression": []
}
EOF

  set +e
  http_code="$(
    curl -sS -o "${raw_base}.json" -w '%{http_code}' \
      -X POST "${CONSUMER_BASE}/management/v3/edrs/request" \
      -H "Authorization: Bearer ${CONSUMER_JWT}" \
      -H "Content-Type: application/json" \
      -d "@${req_file}"
  )"
  curl_exit=$?
  set -e

  printf '%s\n' "${http_code}" > "${PHASE4_DIR}/31_edrs_request.http"

  if (( curl_exit != 0 )) || [[ ! "${http_code}" =~ ^2[0-9]{2}$ ]]; then
    lib_log WARN "Fallback phase4 edrs/request falló: HTTP=${http_code} curl_exit=${curl_exit}"
    return 1
  fi

  _phase4_redact_edr_file "${raw_base}.json" "${PHASE4_DIR}/31_edrs_request_redacted.json"
  _phase4_select_edr_entry "${raw_base}.json" "${selected_file}" || return 1

  if [[ ! -s "${selected_file}" ]] || ! jq -e . "${selected_file}" >/dev/null 2>&1; then
    return 1
  fi

  url="$(_phase4_extract_edr_url "${selected_file}")"
  if ! _phase4_id_is_set "${url}"; then
    return 1
  fi

  PHASE4_EDR_RAW_FILE="${selected_file}"
  PHASE4_EDR_HTTP="${http_code}"
  return 0
}

_phase4_obtain_edr() {
  if _phase4_poll_edr_direct; then
    PHASE4_EDR_SOURCE="direct"
  else
    lib_log WARN "EDR directo no disponible en phase4; probando fallback edrs/request"
    if _phase4_fetch_edr_fallback; then
      PHASE4_EDR_SOURCE="fallback"
    else
      lib_die "No hay EDR resoluble en phase4 (directo ni listado edrs/request)"
    fi
  fi

  _phase4_finalize_edr "${PHASE4_EDR_RAW_FILE}"
}

_phase4_attempt_is_successful() {
  local attempt_file="$1"
  local http_code="$2"
  local curl_exit="$3"
  local bytes

  (( curl_exit == 0 )) || return 1
  [[ "${http_code}" =~ ^2[0-9]{2}$ ]] || return 1
  [[ -f "${attempt_file}" ]] || return 1

  bytes="$(_phase4_file_bytes "${attempt_file}")"
  if (( bytes == 0 )) && [[ "${ALLOW_EMPTY_DOWNLOAD:-}" != "1" ]]; then
    return 1
  fi

  if [[ "${ASSET_CONTENT_KIND}" == "json" ]]; then
    jq empty "${attempt_file}" 2>/dev/null || return 1
  fi

  return 0
}

_phase4_write_data_preview() {
  local data_file="$1"
  local preview_file="$2"
  local tmp="${preview_file}.$$"

  if [[ "${ASSET_CONTENT_KIND}" == "json" ]]; then
    jq '
      if type == "array" then .[0:5]
      elif (tostring | length) < 4096 then .
      else {
        _preview: "truncated",
        type: (type),
        length: (if type == "array" then length else null end)
      }
      end
    ' "${data_file}" > "${tmp}"
  else
    jq -n \
      --arg content_kind "${ASSET_CONTENT_KIND}" \
      --arg extension "${ASSET_EXTENSION}" \
      --arg media_type "${ASSET_MEDIA_TYPE}" \
      --argjson bytes "$(_phase4_file_bytes "${data_file}")" \
      '{content_kind: $content_kind, extension: $extension, media_type: $media_type, bytes: $bytes, preview_available: false}' \
      > "${tmp}"
  fi

  mv "${tmp}" "${preview_file}"
}

_phase4_consume_data_with_auth_candidates() {
  local i attempt_n label header http_code curl_exit base attempt_file selected=false success=0
  local summary_file="${PHASE4_DIR}/42_data_attempts_summary.json"
  local summary_tmp="${summary_file}.$$"
  local -a summary_lines=()
  local attempts_json data_bytes data_http_val
  local canonical_file="${PHASE4_DIR}/$(_phase4_data_response_basename)"
  local -a curl_headers=()

  PHASE4_DATA_RESPONSE_FILE="${canonical_file}"
  export PHASE4_DATA_RESPONSE_FILE

  _phase4_build_auth_candidates

  for i in "${!PHASE4_AUTH_CANDIDATE_LABELS[@]}"; do
    attempt_n="$(printf '%02d' "$((i + 1))")"
    label="${PHASE4_AUTH_CANDIDATE_LABELS[$i]}"
    header="${PHASE4_AUTH_CANDIDATE_HEADERS[$i]}"
    base="${PHASE4_DIR}/40_data_response_attempt_${attempt_n}"
    attempt_file="${base}.${ASSET_EXTENSION}"
    selected=false
    curl_headers=(-H "${header}")

    set +e
    http_code="$(
      curl -sS -o "${attempt_file}" -w '%{http_code}' \
        -X GET "${EDR_URL}" \
        "${curl_headers[@]}"
    )"
    curl_exit=$?
    set -e

    printf '%s\n' "${http_code}" > "${base}.http"
    lib_log INFO "[phase4 data ${attempt_n}] label=${label} HTTP=${http_code} curl_exit=${curl_exit}"

    if _phase4_attempt_is_successful "${attempt_file}" "${http_code}" "${curl_exit}"; then
      cp "${attempt_file}" "${canonical_file}"
      cp "${base}.http" "${PHASE4_DIR}/40_data_response.http"
      _phase4_write_data_preview "${canonical_file}" "${PHASE4_DIR}/41_data_preview.json"

      PHASE4_AUTH_CANDIDATE_LABEL="${label}"
      selected=true
      success=1
    fi

    summary_lines+=("$(
      jq -nc \
        --argjson attempt "$((i + 1))" \
        --arg attempt_label "${label}" \
        --argjson http "$((http_code + 0))" \
        --argjson selected "$([[ "${selected}" == true ]] && echo true || echo false)" \
        '{"attempt": $attempt, "label": $attempt_label, "http": $http, "selected": $selected}'
    )")
  done

  attempts_json="$(jq -s '.' <<< "$(printf '%s\n' "${summary_lines[@]}")")"

  if (( success == 1 )); then
    data_bytes="$(_phase4_file_bytes "${canonical_file}")"
    data_http_val="$(tr -d '\n\r' < "${PHASE4_DIR}/40_data_response.http")"
    jq -nc \
      --arg content_kind "${ASSET_CONTENT_KIND}" \
      --arg extension "${ASSET_EXTENSION}" \
      --arg media_type "${ASSET_MEDIA_TYPE}" \
      --arg data_response_file "phase4/$(_phase4_data_response_basename)" \
      --argjson data_http "${data_http_val}" \
      --argjson bytes "${data_bytes}" \
      --argjson attempts "${attempts_json}" \
      '{
        content_kind: $content_kind,
        extension: $extension,
        media_type: $media_type,
        data_response_file: $data_response_file,
        data_http: $data_http,
        bytes: $bytes,
        attempts: $attempts
      }' > "${summary_tmp}"
  else
    jq -nc --argjson attempts "${attempts_json}" '{attempts: $attempts}' > "${summary_tmp}"
  fi

  mv "${summary_tmp}" "${summary_file}"

  if (( success == 1 )); then
    return 0
  fi

  lib_die "No se pudo consumir el endpoint EDR desde phase4. Revisar phase4/40_data_response_attempt_*.${ASSET_EXTENSION} y phase4/42_data_attempts_summary.json"
}

_phase4_validate_prerequisites() {
  local summary_file="${RUN_DIR}/summary.json"

  [[ -f "${summary_file}" ]] || lib_die "No existe ${summary_file}"

  jq -e '.phases.phase3.status == "ok"' "${summary_file}" >/dev/null \
    || lib_die "summary.json: phases.phase3.status != ok"

  lib_require_vars SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID
}

_phase4_write_manifest() {
  local dest="$1"
  local tmp="${dest}.$$"

  jq -n \
    --arg suffix "${SUFFIX}" \
    --arg asset_id "${ASSET_ID}" \
    --arg agreement_id "${AGREEMENT_ID}" \
    --arg transfer_id "${TRANSFER_ID}" \
    --arg edr_url "$(_phase4_safe_edr_url)" \
    --arg content_kind "${ASSET_CONTENT_KIND}" \
    --arg extension "${ASSET_EXTENSION}" \
    --arg media_type "${ASSET_MEDIA_TYPE}" \
    --arg source_artifact "evidencias/runs/${SUFFIX}/phase4/40_data_response.${ASSET_EXTENSION}" \
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
    --arg auth_candidate_label "${PHASE4_AUTH_CANDIDATE_LABEL}" \
    --argjson edr_url_redacted "$(_phase4_edr_url_has_sensitive_params "${EDR_URL:-}" && echo true || echo false)" \
    '{
      suffix: $suffix,
      asset_id: $asset_id,
      agreement_id: $agreement_id,
      transfer_id: $transfer_id,
      edr_url: $edr_url,
      edr_url_redacted: $edr_url_redacted,
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
      copy_action: $copy_action,
      auth_candidate_label: $auth_candidate_label
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
  || ! _phase4_id_is_set "${TRANSFER_ID:-}"; then
  if [[ ! -f "$(lib_phase_env_path 3)" ]]; then
    lib_die "Ejecuta primero phase3_transfer_edr.sh"
  fi
  # shellcheck source=/dev/null
  source "$(lib_phase_env_path 3)"
fi

lib_load_env
lib_require_cmds
_phase4_require_sha256
lib_require_vars_group LIB_VARS_CONSUMER
lib_require_vars SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID
_phase4_apply_asset_content_defaults
lib_init_run_dirs
lib_init_summary

PHASE4_DIR="${RUN_DIR}/phase4"
DOWNLOADS_DIR="${API_ROOT}/downloads"
mkdir -p "${PHASE4_DIR}" "${DOWNLOADS_DIR}"
export PHASE4_DIR DOWNLOADS_DIR

PHASE4_STEP="jwt_renew"
lib_renew_jwt consumer
lib_jwt_check_console consumer

PHASE4_STEP="jwt_claims"
lib_jwt_claims_to_json consumer "${PHASE4_DIR}/jwt_claims_consumer.json"
lib_write_summary 4 jwt_consumer ok '{"artifact":"phase4/jwt_claims_consumer.json"}'

# ---------------------------------------------------------------------------
# Validaciones + EDR runtime
# ---------------------------------------------------------------------------

PHASE4_STEP="validate"
_phase4_validate_prerequisites

PHASE4_STEP="edr_obtained"
_phase4_obtain_edr
[[ -n "${EDR_URL:-}" && "${EDR_URL}" != "null" ]] || lib_die "EDR_URL no quedó disponible en phase4"
lib_write_summary 4 edr_obtained ok \
  "$(jq -nc \
    --argjson http "${PHASE4_EDR_HTTP}" \
    --arg transfer_id "${TRANSFER_ID}" \
    --arg edr_url "$(_phase4_safe_edr_url)" \
    --arg source "${PHASE4_EDR_SOURCE}" \
    --arg artifact "phase4/30_edr_dataaddress_redacted.json" \
    --argjson edr_url_redacted "$(_phase4_edr_url_has_sensitive_params "${EDR_URL:-}" && echo true || echo false)" \
    '{http: $http, transfer_id: $transfer_id, edr_url: $edr_url, source: $source, artifact: $artifact, edr_url_redacted: $edr_url_redacted}')"

# ---------------------------------------------------------------------------
# Descarga efectiva
# ---------------------------------------------------------------------------

PHASE4_STEP="data_consumed"
_phase4_consume_data_with_auth_candidates

DATA_HTTP="$(tr -d '\n\r' < "${PHASE4_DIR}/40_data_response.http")"
SOURCE_DATA_FILE="${PHASE4_DATA_RESPONSE_FILE}"

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

_phase4_assert_no_sensitive_control_artifact "${PHASE4_DIR}/30_edr_dataaddress_redacted.json"
_phase4_assert_no_sensitive_control_artifact "${PHASE4_DIR}/30_edr_dataaddress_keys.json"
_phase4_assert_no_sensitive_control_artifact "${PHASE4_DIR}/31_edrs_request_body.json"
_phase4_assert_no_sensitive_control_artifact "${PHASE4_DIR}/31_edrs_request_redacted.json"
_phase4_assert_no_sensitive_control_artifact "${PHASE4_DIR}/42_data_attempts_summary.json"
_phase4_assert_no_sensitive_control_artifact "${MANIFEST_FILE}"
_phase4_assert_no_sensitive_control_artifact "${LATEST_MANIFEST}"
_phase4_assert_no_sensitive_control_artifact "${PHASE4_DIR}/download_manifest.json"
_phase4_assert_no_sensitive_control_artifact "${PHASE4_DIR}/download_summary.json"

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
    --arg auth_candidate_label "${PHASE4_AUTH_CANDIDATE_LABEL}" \
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
      data_http: $data_http,
      auth_candidate_label: $auth_candidate_label
    }')"

_phase4_assert_no_sensitive_control_artifact "${RUN_DIR}/summary.json"
lib_set_phase_status 4 ok

trap - ERR
_phase4_cleanup
lib_log INFO "Fase 4 OK — download_file=downloads/assets/${SAFE_ASSET_ID}/latest.${ASSET_EXTENSION} sha256=${FILE_SHA256}"
