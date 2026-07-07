# Evidencias generadas

Cada ejecución de los scripts genera evidencias técnicas locales. Estas evidencias sirven para comprobar qué se hizo, qué respondió el EdD y qué resultado tuvo cada fase.

No se deben versionar evidencias locales ni descargas generadas.

## Identificador de ejecución

El identificador de ejecución usado por este repositorio es `SUFFIX`.

`SUFFIX` se genera en:

```text
export_suffix.sh
```

El valor se calcula con:

```bash
date +%s
```

En este repositorio no hay una variable principal llamada `run_id` ni `correlation_id`. Si alguien habla de run, ejecución o correlación, en la práctica debe mirar `SUFFIX`.

Ejemplo:

```text
SUFFIX=1783070399
```

## Carpeta por ejecución

Cada ejecución crea una carpeta:

```text
evidencias/runs/<SUFFIX>/
```

Ejemplo:

```text
evidencias/runs/1783070399/
```

Dentro se guardan fases, artefactos HTTP y `summary.json`.

## Fases registradas

El flujo HTTP B1 usa:

```text
phase0/
phase1/
phase2/
phase3/
phase4/
```

El flujo InesDataStore B2 usa:

```text
phase0/
phase1b/
phase2/
phase3b/
phase4b/
```

Cada fase guarda ficheros como:

```text
<paso>.json
<paso>.http
```

`<paso>.json` contiene el body guardado. `<paso>.http` contiene el código HTTP.

## `summary.json`

Cada run tiene:

```text
evidencias/runs/<SUFFIX>/summary.json
```

`summary.json` resume la ejecución completa. Incluye:

- `suffix`;
- `ds_name`;
- fecha de inicio;
- fases ejecutadas;
- estado de cada fase;
- pasos registrados;
- metadatos no sensibles de cada paso.

Ejemplo estructural seguro:

```json
{
  "suffix": "<SUFFIX>",
  "ds_name": "ippcp",
  "started_at": "2026-07-03T09:20:00Z",
  "phases": {
    "phase0": {
      "status": "ok",
      "steps": [
        {
          "id": "jwt_provider",
          "status": "ok",
          "artifact": "phase0/jwt_claims_provider.json"
        }
      ]
    },
    "phase1": {
      "status": "ok",
      "steps": [
        {
          "id": "create_asset",
          "status": "ok",
          "asset_id": "<ASSET_ID>",
          "asset_config": "<ASSET_CONFIG>"
        }
      ]
    },
    "phase2": {
      "status": "ok",
      "steps": [
        {
          "id": "contract_negotiation",
          "status": "ok",
          "agreement_id": "<AGREEMENT_ID>"
        }
      ]
    },
    "phase3": {
      "status": "ok",
      "steps": [
        {
          "id": "transfer",
          "status": "ok",
          "transfer_id": "<TRANSFER_ID>"
        }
      ]
    },
    "phase4": {
      "status": "ok",
      "steps": [
        {
          "id": "save_download",
          "status": "ok",
          "sha256": "<SHA256>"
        }
      ]
    }
  }
}
```

No debe contener:

- passwords;
- tokens completos;
- refresh tokens;
- client secrets;
- claves S3 sin redactar.

## Claims JWT seguros

Los scripts no guardan JWT completos. Guardan claims seguros en:

```text
phase0/jwt_claims_provider.json
phase0/jwt_claims_consumer.json
```

Esos ficheros incluyen datos como:

```text
role
iat
exp
now
token_length
```

No incluyen el token completo.

## Descargas y manifests

Las descargas se guardan en:

```text
downloads/assets/<ASSET_ID>/<SUFFIX>.<extension>
downloads/assets/<ASSET_ID>/latest.<extension>
```

Los manifests se guardan en:

```text
downloads/manifests/<ASSET_ID>/<SUFFIX>.manifest.json
downloads/manifests/<ASSET_ID>/latest.manifest.json
```

El manifest permite comprobar:

- `suffix`;
- `asset_id`;
- tipo de contenido;
- extensión;
- fichero descargado;
- bytes;
- `sha256`;
- origen de la descarga.

## Runs IPPCP validados

Estos son los runs validados sobre el dataspace actual `ippcp`:

```text
T1 ingesta / Excel-CSV
SUFFIX=1783070399
ASSET_ID=ippcp_ingesta_bbdd_residencial_2021_csv-1783070399

T2 HTTP WFS
SUFFIX=1783070513
ASSET_ID=ippcp_emisiones_wfs_ciudad_geojson-1783070513

T3 HTTP SPARQL
SUFFIX=1783070583
ASSET_ID=ippcp_emisiones_sparql_limit10_format_json-1783070583
```

## Entrega Excel y ZIP

La configuración de entrega está en:

```text
tools/evidence_export.tests.yaml
```

Herramientas:

```text
tools/export_evidence_to_excel.py
tools/package_evidence_bundle.py
```

Instala dependencias:

```bash
pip install -r tools/requirements-evidence-export.txt
```

Genera una entrega timestamped:

```bash
TS=$(date +%Y%m%d_%H%M%S)
EXPORT_DIR="reports/exports/$TS"

python tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --sanitize-connectors \
  --redact-local-paths \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --verbose

python tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --excel "$EXPORT_DIR/ippcp_evidence_summary_${TS}.xlsx" \
  --sanitize-connectors \
  --redact-local-paths \
  --include-downloaded-assets \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --verbose
```

Resultado:

```text
reports/exports/<TIMESTAMP>/
  ippcp_evidence_summary_<TIMESTAMP>.xlsx
  ippcp_evidence_package_<TIMESTAMP>.zip
```

## Relación con la trazabilidad del EdD

Las evidencias registran:

- llamadas realizadas al Management API;
- estados de negociación;
- acuerdos obtenidos;
- transferencias iniciadas;
- EDR obtenido en flujos HTTP;
- descarga final verificada;
- hashes de contenido.

El EdD por sí solo puede demostrar parte del estado interno de contratos y transferencias. Este repositorio añade trazabilidad de ejecución: qué comando se lanzó, qué asset config se usó, qué ficheros se descargaron y qué hash se verificó.

## Qué revisar antes de entregar evidencias

Comprueba el summary:

```bash
jq . "evidencias/runs/<SUFFIX>/summary.json"
```

Comprueba manifest:

```bash
jq . "downloads/manifests/<ASSET_ID>/latest.manifest.json"
```

Comprueba que el ZIP no contiene secretos:

```bash
ZIP_PATH="reports/exports/<TIMESTAMP>/ippcp_evidence_package_<TIMESTAMP>.zip"
TMP_AUDIT=$(mktemp -d)

unzip -q "$ZIP_PATH" -d "$TMP_AUDIT"

grep -RIE 'secretAccessKey|accessKeyId|eyJ[A-Za-z0-9_-]{20,}' "$TMP_AUDIT" && echo FAIL || echo OK

rm -rf "$TMP_AUDIT"
unzip -t "$ZIP_PATH"
```

No subas `reports/`, `evidencias/runs/`, `downloads/assets/` ni `downloads/manifests/` salvo que se haya definido explícitamente una entrega sanitizada.

## Inspección posterior a cada prueba

Para inspeccionar varias pruebas seguidas, no dependas solo de `runtime/env/latest/phase*_env.sh`. Esos ficheros apuntan a la última ejecución de cada fase y pueden mezclar T1, T2 y T3 si se ejecutaron una detrás de otra.

Fija explícitamente el run que quieres revisar:

```bash
export SUFFIX=<SUFFIX_DE_LA_PRUEBA>
export ASSET_ID=<ASSET_ID_DE_LA_PRUEBA>

RUN_DIR="evidencias/runs/$SUFFIX"
ASSET_DIR="downloads/assets/$ASSET_ID"
MANIFEST_DIR="downloads/manifests/$ASSET_ID"
```

Comprueba rutas:

```bash
echo "RUN_DIR=$RUN_DIR"
echo "ASSET_DIR=$ASSET_DIR"
echo "MANIFEST_DIR=$MANIFEST_DIR"

ls "$RUN_DIR"
ls "$ASSET_DIR"
ls "$MANIFEST_DIR"
```

Vista compacta del summary:

```bash
jq '{suffix, ds_name, started_at, phases}' "$RUN_DIR/summary.json"
```

Manifest:

```bash
jq . "$MANIFEST_DIR/latest.manifest.json"
```

Campos clave:

```text
suffix
asset_id
content_kind
extension
media_type
download_file
latest_file
bytes
sha256
source
```

Comprobar hash del `latest`:

```bash
LATEST_FILE=$(jq -r '.latest_file' "$MANIFEST_DIR/latest.manifest.json")
EXPECTED_SHA=$(jq -r '.sha256' "$MANIFEST_DIR/latest.manifest.json")
ACTUAL_SHA=$(shasum -a 256 "$LATEST_FILE" | awk '{print $1}')

echo "EXPECTED_SHA=$EXPECTED_SHA"
echo "ACTUAL_SHA=$ACTUAL_SHA"

[ "$EXPECTED_SHA" = "$ACTUAL_SHA" ] && echo OK || echo FAIL
```

### Comprobaciones específicas

T1 ingesta CSV:

```bash
LOCAL_FILE="data/real/ingesta/BBDD_Residencial_2021.csv"
LATEST_FILE="$ASSET_DIR/latest.csv"

wc -c "$LOCAL_FILE" "$LATEST_FILE"
shasum -a 256 "$LOCAL_FILE" "$LATEST_FILE"
```

T2 WFS GeoJSON:

```bash
export LATEST_FILE="$ASSET_DIR/latest.json"

python3 - <<'PY'
import json, os
path = os.environ["LATEST_FILE"]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
print("type =", data.get("type"))
features = data.get("features", [])
print("features =", len(features))
PY
```

T3 SPARQL JSON:

```bash
export LATEST_FILE="$ASSET_DIR/latest.json"

python3 - <<'PY'
import json, os
path = os.environ["LATEST_FILE"]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
print("keys =", list(data.keys()))
print("vars =", data.get("head", {}).get("vars"))
print("bindings =", len(data.get("results", {}).get("bindings", [])))
PY
```

Señales de alerta:

- `summary.json` mezcla suffixes: se cargó un env viejo o faltó limpiar variables.
- `latest.json` contiene datos de demo no esperados: se ejecutó Fase 1 sin `ASSET_CONFIG` real.
- No existe `latest.manifest.json`: Fase 4 o Fase 4b no cerró correctamente.
- `expected str, bytes or os.PathLike object, not NoneType`: probablemente `LATEST_FILE` no fue exportado antes del heredoc Python.
