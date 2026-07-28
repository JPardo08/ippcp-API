# Legacy reproducibility only. IPPCP v2 is the current recommended route.
# === Consumer (ingesta) — conn-citycouncil ===
export CONSUMER="conn-citycouncil-ippcp"
export CONSUMER_HOST="${CONSUMER}.${DS_DOMAIN}"
export CONSUMER_BASE="https://${CONSUMER_HOST}"
export CONSUMER_PROTOCOL="http://${CONSUMER}:19194/protocol"
