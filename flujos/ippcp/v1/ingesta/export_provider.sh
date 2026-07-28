# Legacy reproducibility only. IPPCP v2 is the current recommended route.
# === Provider (ingesta) — conn-company ===
export PROVIDER="conn-company-ippcp"
export PROVIDER_HOST="${PROVIDER}.${DS_DOMAIN}"
export PROVIDER_BASE="https://${PROVIDER_HOST}"
export PROVIDER_PROTOCOL="http://${PROVIDER}:19194/protocol"
