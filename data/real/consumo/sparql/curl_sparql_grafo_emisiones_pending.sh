#!/usr/bin/env bash
set -euo pipefail

if [[ "${ALLOW_PENDING:-0}" != "1" ]]; then
  echo "Este endpoint está marcado como pendiente. Ejecuta con ALLOW_PENDING=1 solo tras confirmar publicación del grafo."
  exit 1
fi

OUT_DIR="${OUT_DIR:-data/real/consumo/responses}"
mkdir -p "${OUT_DIR}"

QUERY='SELECT ?s ?p ?o WHERE { GRAPH <http://www.zaragoza.es/medio-ambiente/emisiones/> { ?s ?p ?o } } LIMIT 10'

curl -sS -L --fail --get \
  "https://datos.zaragoza.es/sparql" \
  -H "Accept: application/sparql-results+json" \
  --data-urlencode "query=${QUERY}" \
  -o "${OUT_DIR}/emisiones_sparql_grafo_emisiones_pending.json"

echo "SPARQL grafo emisiones guardado en ${OUT_DIR}/emisiones_sparql_grafo_emisiones_pending.json"
