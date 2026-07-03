#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-data/real/consumo/responses/sparql_format_tests}"
mkdir -p "${OUT_DIR}"

QUERY='SELECT * WHERE { ?s ?p ?o } LIMIT 10'

curl -sS -L --fail --get \
  "https://datos.zaragoza.es/sparql" \
  --data-urlencode "query=${QUERY}" \
  -o "${OUT_DIR}/sparql_no_accept.response"

echo "SPARQL no Accept guardado en ${OUT_DIR}/sparql_no_accept.response"
