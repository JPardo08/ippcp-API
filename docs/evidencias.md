# Evidencias Generadas

Cada ejecución de los scripts genera evidencias técnicas locales. Estas evidencias sirven para comprobar qué se hizo, qué respondió el EdD y qué resultado tuvo cada fase.

No se deben versionar evidencias locales ni descargas generadas.

## Identificador De Ejecución

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

## Carpeta Por Ejecución

Cada ejecución crea una carpeta:

```text
evidencias/runs/<SUFFIX>/
```

Ejemplo:

```text
evidencias/runs/1783070399/
```

Dentro se guardan fases, artefactos HTTP y `summary.json`.

## Fases Registradas

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

## Claims JWT Seguros

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

## Descargas Y Manifests

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

## Runs IPPCP Validados

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

## Entrega Excel Y ZIP

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

## Relación Con La Trazabilidad Del EdD

Las evidencias registran:

- llamadas realizadas al Management API;
- estados de negociación;
- acuerdos obtenidos;
- transferencias iniciadas;
- EDR obtenido en flujos HTTP;
- descarga final verificada;
- hashes de contenido.

El EdD por sí solo puede demostrar parte del estado interno de contratos y transferencias. Este repositorio añade trazabilidad de ejecución: qué comando se lanzó, qué asset config se usó, qué ficheros se descargaron y qué hash se verificó.

## Qué Revisar Antes De Entregar Evidencias

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
