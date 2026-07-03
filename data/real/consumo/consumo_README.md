# Consumo real IPPCP

Este directorio contiene llamadas HTTP/curl de referencia para los assets reales de consumo de emisiones de Zaragoza.

## WFS

Endpoint base:

`https://idezar-sig.zaragoza.es/servicios/geoserver/medioambiente/wfs`

Capas usadas:

- `medioambiente:emisiones_agregados_juntas`
- `medioambiente:emisiones_agregados_ciudad`

Scripts (`data/real/consumo/wfs/`):

- `curl_wfs_juntas_geojson.sh`
- `curl_wfs_ciudad_geojson.sh`

Ambos devuelven GeoJSON / JSON con `count=10`.

## SPARQL

Endpoint:

`https://datos.zaragoza.es/sparql`

Script operativo (`data/real/consumo/sparql/`):

- `curl_sparql_limit10.sh`

Usa header:

`Accept: application/sparql-results+json`

## SPARQL — variantes de formato sin Accept

Además del curl operativo con `Accept: application/sparql-results+json`, existen scripts en `data/real/consumo/sparql/` para probar si el endpoint permite forzar JSON mediante parámetros de URL:

- `curl_sparql_limit10_no_accept.sh`
- `curl_sparql_limit10_format_mime.sh`
- `curl_sparql_limit10_format_json.sh`
- `curl_sparql_limit10_output_json.sh`
- `test_sparql_format_variants.sh`

El objetivo es encontrar una URL que devuelva JSON sin depender de headers HTTP custom, porque la automatización B1 actual no propaga `Accept` hacia el endpoint final.

**Variante ganadora validada:** `format=application/sparql-results+json` (`format_mime`). En el `base_url` el carácter `+` debe codificarse como `%2B`.

Config EdD operativo: `asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json`

Script pendiente:

- `curl_sparql_grafo_emisiones_pending.sh`

No ejecutar salvo confirmación de publicación del grafo de emisiones. Requiere:

`ALLOW_PENDING=1`

## Relación con asset_configs

- `asset_configs/real/consumo/wfs/emisiones_wfs_juntas_geojson.json`
- `asset_configs/real/consumo/wfs/emisiones_wfs_ciudad_geojson.json`
- `asset_configs/real/consumo/sparql/emisiones_sparql_limit10.json` (bloqueado sin Accept; usar `emisiones_sparql_limit10_format_json.json`)
- `asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json` (variante ganadora: `format=application/sparql-results+json`)
- `asset_configs/real/consumo/sparql/emisiones_sparql_grafo_emisiones_pending.json`

Respuestas generadas por los curls: `data/real/consumo/responses/` (ignorado por Git).
