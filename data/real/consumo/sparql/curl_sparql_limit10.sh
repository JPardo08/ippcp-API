#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-data/real/consumo/responses}"
mkdir -p "${OUT_DIR}"

QUERY='SELECT * WHERE { ?s ?p ?o } LIMIT 10'

curl -sS -L --fail --get \
  "https://datos.zaragoza.es/sparql" \
  -H "Accept: application/sparql-results+json" \
  --data-urlencode "query=${QUERY}" \
  -o "${OUT_DIR}/emisiones_sparql_limit10.json"

echo "SPARQL limit10 guardado en ${OUT_DIR}/emisiones_sparql_limit10.json"
