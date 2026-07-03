#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-data/real/consumo/responses}"
mkdir -p "${OUT_DIR}"

curl -sS -L --fail --get \
  "https://idezar-sig.zaragoza.es/servicios/geoserver/medioambiente/wfs" \
  -H "Accept: application/json" \
  --data-urlencode "service=WFS" \
  --data-urlencode "version=2.0.0" \
  --data-urlencode "request=GetFeature" \
  --data-urlencode "typeNames=medioambiente:emisiones_agregados_ciudad" \
  --data-urlencode "outputFormat=application/json" \
  --data-urlencode "count=10" \
  -o "${OUT_DIR}/emisiones_wfs_ciudad_geojson.json"

echo "WFS ciudad guardado en ${OUT_DIR}/emisiones_wfs_ciudad_geojson.json"
