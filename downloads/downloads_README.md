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
