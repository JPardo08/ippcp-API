# Datos reales IPPCP

## Consumo / salidas

- WFS juntas GeoJSON: `asset_configs/real/consumo/wfs/emisiones_wfs_juntas_geojson.json`
- WFS ciudad GeoJSON: `asset_configs/real/consumo/wfs/emisiones_wfs_ciudad_geojson.json`
- SPARQL limit10 (bloqueado sin Accept): `asset_configs/real/consumo/sparql/emisiones_sparql_limit10.json`
- SPARQL limit10 operativo (format URL): `asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json` — variante ganadora `format=application/sparql-results+json`
- SPARQL grafo emisiones: pending, no ejecutar hasta publicación del grafo
- Scripts curl de referencia WFS: `data/real/consumo/wfs/`
- Scripts curl de referencia SPARQL: `data/real/consumo/sparql/`

## Ingesta

- `data/real/ingesta/BBDD_Residencial_2021.csv` (local, no versionado provisionalmente — ver `data/real/ingesta/ingesta_README.md`)
- Config B2: `asset_configs/real/ingesta/ingesta_bbdd_residencial_2021_csv.json`
- Ingesta API tentativa (pending): `asset_configs/real/ingesta/ingesta_api_tentativa.pending.json`

## Nota

Los endpoints WFS/SPARQL publican inventario/resultados de emisiones, no datos brutos de empresas.
La ingesta real vía API/Data Plane queda pendiente de confirmación del endpoint municipal.
