# IPPCP evidence delivery tools

Herramientas read-only para transformar evidencias locales en artefactos de entrega:

```text
evidencias originales -> Excel resumen -> ZIP sanitizado -> auditoría anti-secretos
```

No modifican `evidencias/runs/`, `downloads/` ni los scripts Bash de fase.

## Instalación

Se recomienda Python 3.10 o superior para ejecutar las herramientas de entrega. Si usas Conda:

```bash
conda create -n data_spaces_310 python=3.10 -y
conda activate data_spaces_310
python --version
```

Instala dependencias desde la raíz del repo:

```bash
python3 -m pip install -r tools/requirements-evidence-export.txt
```

Dependencias principales:

- `openpyxl` para Excel.
- `PyYAML` para la configuración compartida.

## Configuración

El fichero `tools/evidence_export.tests.yaml` define:

- Tests T1/T2/T3 y sus suffixes.
- Alias públicos de conectores.
- Semántica esperada de roles por flujo.

Runs finales configurados actualmente:

- T1 ingesta / Excel-CSV: `1783070399`
- T2 WFS ciudad: `1783070513`
- T3 SPARQL: `1783070583`

Suffixes históricos conservados como contexto en `tools/evidence_export.tests.yaml`:

- T1 histórico: `1782294549`
- T2 histórico: `1782299532`
- T3 histórico: `1782299641`

Si se repiten pruebas en el futuro, actualizar explícitamente `tools/evidence_export.tests.yaml` antes de generar una nueva entrega.

## Exportar Excel

```bash
python tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --sanitize-connectors \
  --redact-local-paths \
  --output reports/ippcp_evidence_summary.xlsx \
  --verbose
```

El Excel incluye:

- `Summary`
- Una hoja por test
- `Raw JSON Index`
- `Evidence Checklist`
- `Package Manifest`

Si un campo no existe en los JSON, se escribe `not_found`.

## Entrega timestamped recomendada

Para evitar mezclar Excel/ZIP antiguos con nuevos runs T2/T3, generar cada entrega en una carpeta dedicada:

```bash
export T1_SUFFIX=1783070399
export T2_SUFFIX=1783070513
export T3_SUFFIX=1783070583

TS=$(date +%Y%m%d_%H%M%S)
EXPORT_DIR="reports/exports/$TS"
TESTS="T1=$T1_SUFFIX,T2=$T2_SUFFIX,T3=$T3_SUFFIX"

python tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --tests "$TESTS" \
  --sanitize-connectors \
  --redact-local-paths \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --verbose
```

Antes de crear el ZIP definitivo, revisa qué entraría en el paquete:

```bash
python tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --tests "$TESTS" \
  --excel "$EXPORT_DIR/ippcp_evidence_summary_${TS}.xlsx" \
  --sanitize-connectors \
  --redact-local-paths \
  --include-downloaded-assets \
  --dry-run \
  --verbose
```

Crear ZIP final usando el mismo `TS` y `EXPORT_DIR`:

```bash
python tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --tests "$TESTS" \
  --excel "$EXPORT_DIR/ippcp_evidence_summary_${TS}.xlsx" \
  --sanitize-connectors \
  --redact-local-paths \
  --include-downloaded-assets \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --verbose
```

Resultado esperado:

```text
reports/exports/<TIMESTAMP>/
  ippcp_evidence_summary_<TIMESTAMP>.xlsx
  ippcp_evidence_package_<TIMESTAMP>.zip
```

Notas de entrega:

- T1 ingesta / Excel-CSV: `1783070399`.
- T2 WFS ciudad: `1783070513`.
- T3 SPARQL: `1783070583`.
- Si se repiten pruebas en el futuro, actualizar explícitamente `tools/evidence_export.tests.yaml` antes de generar una nueva entrega.
- Los ficheros bajo `reports/exports/<TIMESTAMP>/` son artefactos de entrega regenerables.
- Las evidencias originales bajo `evidencias/runs/` no se modifican.

## Crear ZIP

Primero se puede revisar qué entraría sin crear ZIP:

```bash
python tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --excel reports/ippcp_evidence_summary.xlsx \
  --sanitize-connectors \
  --redact-local-paths \
  --include-downloaded-assets \
  --dry-run \
  --verbose
```

Crear paquete final:

```bash
python tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --excel reports/ippcp_evidence_summary.xlsx \
  --sanitize-connectors \
  --redact-local-paths \
  --include-downloaded-assets \
  --output reports/ippcp_evidence_package.zip \
  --verbose
```

## Política de seguridad

Exclusiones obligatorias:

- `*.sensitive.json`
- `*.secret.json`
- `phase*_env.sh`
- `runtime/env/**`
- `flujos/**/user_*.sh`
- `*.body`
- JSONs con credenciales/JWTs no redactados

`phase3b/21_transfer_final_state.sensitive.json` se registra como excluido en manifiestos, pero no se abre ni se copia.

La sanitización solo se aplica sobre copias de salida:

- `conn-erick-test3` -> `conn-company-ippcp`
- `conn-edgar-test3` -> `conn-citycouncil-ippcp`
- `test3-conn-erick-test3` -> `test3-conn-company-ippcp`
- `test3-conn-edgar-test3` -> `test3-conn-citycouncil-ippcp`

Las rutas absolutas del repo se redactan como `<repo-root>` con `--redact-local-paths`.

## Validar originales intactos

Ejemplo para T1:

```bash
find evidencias/runs/1783070399 -type f -exec shasum -a 256 {} \; > /tmp/before.sha256

python tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --excel reports/ippcp_evidence_summary.xlsx \
  --sanitize-connectors \
  --redact-local-paths \
  --include-downloaded-assets \
  --output reports/ippcp_evidence_package.zip

find evidencias/runs/1783070399 -type f -exec shasum -a 256 {} \; > /tmp/after.sha256
diff -u /tmp/before.sha256 /tmp/after.sha256
```

## Auditoría manual del ZIP

Esta comprobación valida el contenido real descomprimido del paquete sanitizado.

```bash
ZIP_PATH="reports/exports/<TIMESTAMP>/ippcp_evidence_package_<TIMESTAMP>.zip"
TMP_AUDIT=$(mktemp -d)

unzip -q "$ZIP_PATH" -d "$TMP_AUDIT"

grep -RIE 'conn-erick-test3|conn-edgar-test3' "$TMP_AUDIT" && echo FAIL || echo OK

grep -RIE 'secretAccessKey|accessKeyId|eyJ[A-Za-z0-9_-]{20,}' "$TMP_AUDIT" && echo FAIL || echo OK

rm -rf "$TMP_AUDIT"

unzip -t "$ZIP_PATH"
```

Si `unzip` dice que no encuentra el ZIP, normalmente se recalculó `TS` después de generar la entrega. Reutiliza el timestamp real de la carpeta creada en `reports/exports/`.

## Bash en macOS

Los scripts Bash de fase del repo siguen requiriendo Bash moderno:

- Intel/Homebrew clásico: `/usr/local/bin/bash`
- Apple Silicon/Homebrew moderno: `/opt/homebrew/bin/bash`

Estas herramientas Python no sustituyen a los JSON originales; son una capa de resumen, empaquetado y entrega.
