# Downloads locales IPPCP

Este directorio contiene artefactos descargados localmente durante la ejecución de los flujos IPPCP.

## Estructura

```text
downloads/
  assets/
  manifests/
```

## Assets

Las respuestas descargadas de assets B1 / HttpData se guardan en:

```text
downloads/assets/<ASSET_ID>/
```

Ejemplo:

```text
downloads/assets/<ASSET_ID>/latest.json
```

## Manifests

Los manifests asociados a descargas se guardan en:

```text
downloads/manifests/<ASSET_ID>/
```

Ejemplo:

```text
downloads/manifests/<ASSET_ID>/latest.manifest.json
```

Cada descarga conserva, cuando aplica, dos referencias:

```text
downloads/assets/<ASSET_ID>/<SUFFIX>.<extension>
downloads/assets/<ASSET_ID>/latest.<extension>
downloads/manifests/<ASSET_ID>/<SUFFIX>.manifest.json
downloads/manifests/<ASSET_ID>/latest.manifest.json
```

`latest.*` apunta a la última descarga conocida para ese asset. Para auditar una ejecución concreta, usa el `SUFFIX` del run y comprueba que coincide con el manifest.

## Inspección rápida

Selecciona el asset que quieres revisar:

```bash
export ASSET_ID=<ASSET_ID>
MANIFEST_DIR="downloads/manifests/$ASSET_ID"
ASSET_DIR="downloads/assets/$ASSET_ID"
```

Revisa el manifest:

```bash
jq . "$MANIFEST_DIR/latest.manifest.json"
```

Comprueba hash:

```bash
LATEST_FILE=$(jq -r '.latest_file' "$MANIFEST_DIR/latest.manifest.json")
EXPECTED_SHA=$(jq -r '.sha256' "$MANIFEST_DIR/latest.manifest.json")
ACTUAL_SHA=$(shasum -a 256 "$LATEST_FILE" | awk '{print $1}')

echo "EXPECTED_SHA=$EXPECTED_SHA"
echo "ACTUAL_SHA=$ACTUAL_SHA"
[ "$EXPECTED_SHA" = "$ACTUAL_SHA" ] && echo OK || echo FAIL
```

Campos importantes del manifest:

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

## Relación con la entrega de evidencias

`downloads/assets/<ASSET_ID>/latest.<extension>` contiene la copia local descargada.

`downloads/manifests/<ASSET_ID>/latest.manifest.json` es el manifest canónico de trazabilidad de la descarga.

Las herramientas en `tools/` leen estos manifests, junto con `evidencias/runs/`, para construir el Excel y el ZIP de entrega. `reports/exports/` se construye a partir de esas evidencias/manifests, no al revés.

El ZIP incluye copias sanitizadas y, si se usa `--include-downloaded-assets`, también puede incluir el asset descargado.

`downloads/` sigue siendo contenido generado/local/no versionado, salvo `.gitkeep` y documentación.

No editar manifests manualmente para “arreglar” una entrega; si algo cambia, debe regenerarse desde los runs originales.

## Política de Git

La estructura del directorio está versionada, pero los assets y manifests generados no se versionan.

Solo se versionan:

```text
downloads/downloads_README.md
downloads/assets/.gitkeep
downloads/manifests/.gitkeep
```

No guardar aquí credenciales, tokens ni artefactos sensibles.
