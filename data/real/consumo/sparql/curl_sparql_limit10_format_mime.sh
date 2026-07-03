#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-data/real/consumo/responses/sparql_format_tests}"
mkdir -p "${OUT_DIR}"

QUERY='SELECT * WHERE { ?s ?p ?o } LIMIT 10'

curl -sS -L --fail --get \
  "https://datos.zaragoza.es/sparql" \
  --data-urlencode "query=${QUERY}" \
  --data-urlencode "format=application/sparql-results+json" \
  -o "${OUT_DIR}/sparql_format_mime.response"

echo "SPARQL format MIME guardado en ${OUT_DIR}/sparql_format_mime.response"
