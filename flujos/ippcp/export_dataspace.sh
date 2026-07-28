# === Dataspace ===
_ippcp_export_die() {
  echo "ERROR: $*" >&2
  return 1 2>/dev/null || exit 1
}

if [[ -z "${API_ROOT:-}" ]]; then
  _ippcp_search_dir="${PWD}"
  while [[ "${_ippcp_search_dir}" != "/" ]]; do
    if [[ -f "${_ippcp_search_dir}/endpoints.sh" && -f "${_ippcp_search_dir}/export_suffix.sh" && -f "${_ippcp_search_dir}/scripts/lib_common.sh" ]]; then
      API_ROOT="${_ippcp_search_dir}"
      break
    fi
    _ippcp_search_dir="$(dirname "${_ippcp_search_dir}")"
  done

  if [[ -z "${API_ROOT:-}" && -n "${BASH_SOURCE:-}" ]]; then
    _ippcp_dataspace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    API_ROOT="$(cd "${_ippcp_dataspace_dir}/../.." && pwd)"
  fi

  [[ -n "${API_ROOT:-}" ]] \
    || _ippcp_export_die "No se pudo resolver API_ROOT para flujos/ippcp/export_dataspace.sh"
  export API_ROOT
fi

export DS_NAME="ippcp"
export DS_DOMAIN="ds.inesdata-project.eu"
export KEYCLOAK_URL="https://auth.ds.inesdata-project.eu"
export KC_CLIENT="dataspace-users"

export IPPCP_DATASPACE_DIR="${API_ROOT}/flujos/ippcp"
export IPPCP_FLOW_VERSION="${IPPCP_FLOW_VERSION:-v2}"

case "${IPPCP_FLOW_VERSION}" in
  v1|v2) ;;
  *) _ippcp_export_die "IPPCP_FLOW_VERSION inválido: ${IPPCP_FLOW_VERSION} (esperado: v1|v2)" ;;
esac

if [[ -n "${IPPCP_FLOW:-}" ]]; then
  case "${IPPCP_FLOW}" in
    ingesta|consumo) ;;
    *) _ippcp_export_die "IPPCP_FLOW inválido: ${IPPCP_FLOW} (esperado: ingesta|consumo)" ;;
  esac

  if [[ -z "${IPPCP_FLOW_DIR:-}" ]]; then
    export IPPCP_FLOW_DIR="${IPPCP_DATASPACE_DIR}/${IPPCP_FLOW_VERSION}/${IPPCP_FLOW}"
  fi

  [[ -d "${IPPCP_FLOW_DIR}" ]] \
    || _ippcp_export_die "Missing IPPCP flow directory: ${IPPCP_FLOW_DIR}"
  [[ -f "${IPPCP_FLOW_DIR}/export_provider.sh" ]] \
    || _ippcp_export_die "Missing flow export: ${IPPCP_FLOW_DIR}/export_provider.sh"
  [[ -f "${IPPCP_FLOW_DIR}/export_consumer.sh" ]] \
    || _ippcp_export_die "Missing flow export: ${IPPCP_FLOW_DIR}/export_consumer.sh"
fi
