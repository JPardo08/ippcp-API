# === Consumer (consumo) — conn-erick ===
# TODO: confirmar mapeo definitivo de conectores para el flujo consumo si difiere de ingesta.
export CONSUMER="conn-erick-test3"
export CONSUMER_HOST="${CONSUMER}.${DS_DOMAIN}"
export CONSUMER_BASE="https://${CONSUMER_HOST}"
export CONSUMER_PROTOCOL="http://${CONSUMER}:19194/protocol"
