# Inventario del repositorio IPPCP API

Informe de inspección readonly generado para apoyar un plan de limpieza/reorganización posterior.
No se ha movido, borrado ni modificado ningún archivo del repo salvo este informe.

**Fecha de inspección:** 2026-06-19  
**cwd:** `/Users/jpardo/Desktop/EDD/IPPCP/ippcp_API`

---

## 1. Estado Git

### Resumen

| Indicador | Valor |
|-----------|-------|
| cwd | `/Users/jpardo/Desktop/EDD/IPPCP/ippcp_API` |
| Archivos tracked | 32 |
| Modificados (tracked, sin stage) | `.gitignore`, `README.md`, `scripts/README.md` |
| Sin trackear | `asset_configs/real/` (7 JSON), `data/real/` (READMEs, curls, CSV) |
| Nuevo por este inventario | `docs/repo_inventory.md` |

### `git status --short`

```
 M .gitignore
 M README.md
 M scripts/README.md
?? asset_configs/real/
?? data/real/
```

### Ignorados relevantes (`git status --short --ignored`)

```
!! .DS_Store
!! data/.DS_Store
!! data/real/.DS_Store
!! data/real/consumo/responses/
!! downloads/
!! evidencias/
!! phase0_env.sh
!! phase0_env.sh.bak.1781856077
!! phase0_env.sh.bak.1781856503
!! phase0_env.sh.bak.1781856547
!! phase0_env.sh.bak.1781857353
!! phase1_env.sh
!! phase1_env.sh.bak.1781856086
!! phase1_env.sh.bak.1781856512
!! phase1_env.sh.bak.1781856558
!! phase1_env.sh.bak.1781857370
!! phase1b_env.sh
!! phase1b_env.sh.bak.1781856558
!! phase2_env.sh
!! phase2_env.sh.bak.1781856095
!! phase2_env.sh.bak.1781856522
!! phase2_env.sh.bak.1781856567
!! phase2_env.sh.bak.1781857380
!! phase3_env.sh
!! phase3_env.sh.bak.1781856111
!! phase3_env.sh.bak.1781856530
!! phase3_env.sh.bak.1781857388
!! phase3b_env.sh
!! phase3b_env.sh.bak.1781856571
```

### Archivos tracked (`git ls-files`, 32)

```
.gitignore
LICENSE
README.md
asset_configs/examples/emisiones_csv.example.json
asset_configs/examples/emisiones_sparql.example.json
asset_configs/examples/emisiones_wfs.example.json
asset_configs/examples/emisiones_wfs_gml.example.json
asset_configs/examples/ingesta_csv_upload.example.json
asset_configs/examples/ingesta_excel.example.json
asset_configs/http_jsonplaceholder_todos.json
asset_configs/test_csv_public.json
asset_configs/upload/ingesta_csv_empresa_demo.json
data/ingesta_demo.csv
docs/f1_provider.pdf
docs/f2_consumer.pdf
docs/f3_transfer.pdf
docs/taller_api.pdf
endpoints.sh
export_consumer.sh
export_dataspace.sh
export_provider.sh
export_suffix.sh
scripts/README.md
scripts/lib_common.sh
scripts/phase0_context_smoke.sh
scripts/phase1_provider_publish.sh
scripts/phase1b_provider_upload_file.sh
scripts/phase2_consumer_negotiate.sh
scripts/phase3_transfer_edr.sh
scripts/phase3b_inesdata_transfer.sh
scripts/phase4_save_download.sh
scripts/phase4b_consumer_storage_fetch.sh
```

**Nota:** `asset_configs/real/` y `data/real/` existen en disco pero aún no están en Git.

---

## 2. Árbol actual

Árbol filtrado (excluye `.git`, `downloads`, `evidencias/runs`, `data/real/consumo/responses`).

```text
.
├── .gitignore
├── LICENSE
├── README.md
├── asset_configs/
│   ├── examples/                    (6 plantillas *.example.json)
│   ├── real/                        (7 JSON — untracked)
│   ├── http_jsonplaceholder_todos.json
│   ├── test_csv_public.json
│   └── upload/
│       └── ingesta_csv_empresa_demo.json
├── data/
│   ├── ingesta_demo.csv             (demo B2, tracked)
│   └── real/                        (untracked)
│       ├── README.md
│       ├── consumo/
│       │   ├── README.md
│       │   ├── curl_wfs_*.sh        (2)
│       │   ├── curl_sparql_*.sh     (5)
│       │   └── test_sparql_format_variants.sh
│       └── ingesta/
│           └── BBDD_Residencial_2021.csv  (4.3M)
├── docs/
│   ├── f1_provider.pdf
│   ├── f2_consumer.pdf
│   ├── f3_transfer.pdf
│   └── taller_api.pdf
├── endpoints.sh
├── export_consumer.sh               (contenido sensible — no inventariado)
├── export_dataspace.sh
├── export_provider.sh               (contenido sensible — no inventariado)
├── export_suffix.sh
├── phase*_env.sh                    (6 en raíz — ignorados)
├── phase*_env.sh.bak.*              (15 en raíz — ignorados)
├── scripts/
│   ├── README.md
│   ├── lib_common.sh
│   └── phase{0,1,1b,2,3,3b,4,4b}_*.sh
└── evidencias/                      (directorio presente; runs ignorados)
```

**Nota macOS:** el CSV real está en `data/real/ingesta/` (minúsculas). El filesystem es case-insensitive; no existe carpeta paralela `Ingesta/`.

---

## 3. Inventario de asset_configs

Total: **16 JSON** bajo `asset_configs/`.

### Tabla resumida

| path | categoría | asset_slug | type | storage_mode | content_kind | ext |
|------|-----------|------------|------|--------------|--------------|-----|
| `examples/emisiones_csv.example.json` | example_template | emisiones_csv | HttpData | — | text | csv |
| `examples/emisiones_sparql.example.json` | example_template | emisiones_sparql | HttpData | — | json | json |
| `examples/emisiones_wfs.example.json` | example_template | emisiones_wfs | HttpData | — | json | json |
| `examples/emisiones_wfs_gml.example.json` | example_template | emisiones_wfs_gml | HttpData | — | text | gml |
| `examples/ingesta_csv_upload.example.json` | example_template | ingesta_csv_empresa_demo | InesDataStore | inesdatastore | text | csv |
| `examples/ingesta_excel.example.json` | example_template | ingesta_excel_empresa_demo | HttpData | — | binary | xlsx |
| `http_jsonplaceholder_todos.json` | demo_http | jsonplaceholder_todos | HttpData | — | json | json |
| `test_csv_public.json` | demo_http | test_csv_public | HttpData | — | text | csv |
| `upload/ingesta_csv_empresa_demo.json` | demo_upload | ingesta_csv_empresa_demo | InesDataStore | inesdatastore | text | csv |
| `real/emisiones_wfs_juntas_geojson.json` | real_consumo_wfs | ippcp_emisiones_wfs_juntas_geojson | HttpData | — | json | json |
| `real/emisiones_wfs_ciudad_geojson.json` | real_consumo_wfs | ippcp_emisiones_wfs_ciudad_geojson | HttpData | — | json | json |
| `real/emisiones_sparql_limit10.json` | real_consumo_sparql | ippcp_emisiones_sparql_limit10 | HttpData | — | json | json |
| `real/emisiones_sparql_limit10_format_json.json` | real_consumo_sparql | ippcp_emisiones_sparql_limit10_format_json | HttpData | — | json | json |
| `real/ingesta_bbdd_residencial_2021_csv.json` | real_ingesta_b2 | ippcp_ingesta_bbdd_residencial_2021_csv | InesDataStore | inesdatastore | text | csv |
| `real/emisiones_sparql_grafo_emisiones_pending.json` | pending | ippcp_emisiones_sparql_grafo_emisiones_pending | HttpData | — | json | json |
| `real/ingesta_api_tentativa.pending.json` | pending | ippcp_ingesta_api_tentativa | HttpData | — | json | json |

### Detalle por fichero (campos jq)

#### example_template (6)

| path | name | base_url / local_file | keywords |
|------|------|----------------------|----------|
| `examples/emisiones_csv.example.json` | Emisiones CSV | `https://REPLACE_ME/emisiones.csv` | ippcp, emisiones, csv |
| `examples/emisiones_sparql.example.json` | Emisiones SPARQL | `https://REPLACE_ME/sparql?...` | ippcp, emisiones, sparql |
| `examples/emisiones_wfs.example.json` | Emisiones WFS | `https://REPLACE_ME/geoserver/ows?...` | ippcp, emisiones, wfs |
| `examples/emisiones_wfs_gml.example.json` | Emisiones WFS GML | `https://REPLACE_ME/geoserver/ows?...` | ippcp, emisiones, wfs, gml |
| `examples/ingesta_csv_upload.example.json` | Ingesta CSV empresa demo | `local_file`: `data/ingesta_demo.csv`, `store_folder`: ippcp-ingesta | ippcp, ingesta, csv |
| `examples/ingesta_excel.example.json` | Ingesta Excel empresa demo | `https://REPLACE_ME/ingesta_empresa_demo.xlsx` | ippcp, ingesta, excel |

#### demo_http (2)

| path | name | base_url | keywords |
|------|------|----------|----------|
| `http_jsonplaceholder_todos.json` | JSONPlaceholder Todos | `https://jsonplaceholder.typicode.com/todos` | taller, demo, dataspace, json |
| `test_csv_public.json` | Test CSV público | `https://REPLACE_ME/test.csv` | test, csv, b1 |

#### demo_upload (1)

| path | name | local_file | store_folder | upload_file_name |
|------|------|------------|--------------|------------------|
| `upload/ingesta_csv_empresa_demo.json` | Ingesta CSV empresa demo | `data/ingesta_demo.csv` | ippcp-ingesta | ingesta_demo.csv |

**Duplicado funcional:** idéntico en contenido a `examples/ingesta_csv_upload.example.json` (mismo `asset_slug`, `local_file`, etc.).

#### real_consumo_wfs (2)

| path | name | base_url (resumido) |
|------|------|---------------------|
| `real/emisiones_wfs_juntas_geojson.json` | IPPCP emisiones WFS juntas GeoJSON | idezar-sig…/emisiones_agregados_juntas |
| `real/emisiones_wfs_ciudad_geojson.json` | IPPCP emisiones WFS ciudad GeoJSON | idezar-sig…/emisiones_agregados_ciudad |

#### real_consumo_sparql (2)

| path | name | base_url (resumido) |
|------|------|---------------------|
| `real/emisiones_sparql_limit10.json` | IPPCP emisiones SPARQL validación | datos.zaragoza.es/sparql (sin format URL) |
| `real/emisiones_sparql_limit10_format_json.json` | IPPCP emisiones SPARQL validación format JSON | datos.zaragoza.es/sparql + `format=application/sparql-results+json` |

#### real_ingesta_b2 (1)

| path | name | local_file | store_folder | upload_file_name |
|------|------|------------|--------------|------------------|
| `real/ingesta_bbdd_residencial_2021_csv.json` | IPPCP ingesta BBDD residencial 2021 CSV | `data/real/ingesta/BBDD_Residencial_2021.csv` | ippcp-ingesta | BBDD_Residencial_2021.csv |

#### pending (2)

| path | name | base_url (resumido) |
|------|------|---------------------|
| `real/emisiones_sparql_grafo_emisiones_pending.json` | IPPCP emisiones SPARQL grafo emisiones (pending) | datos.zaragoza.es/sparql (GRAPH emisiones) |
| `real/ingesta_api_tentativa.pending.json` | IPPCP ingesta API tentativa | idezar-sig…/ippcp-ingesta/ingesta/upload |

### Observaciones

- `asset_configs/real/` está plano; debería separarse en `consumo/wfs`, `consumo/sparql` e `ingesta`.
- `http_jsonplaceholder_todos.json` y `test_csv_public.json` son demos HTTP en la raíz de `asset_configs/`, no configs reales.
- `upload/ingesta_csv_empresa_demo.json` es demo B2; duplica la plantilla de `examples/`.
- `test_csv_public.json` no aparece referenciado en README ni scripts.

---

## 4. Inventario de data/real

### `data/real/consumo/` (scripts de referencia)

| path | tipo probable | tamaño | origen | versionar |
|------|---------------|--------|--------|-----------|
| `consumo/README.md` | documentación | 2.0K | fuente | sí |
| `consumo/curl_wfs_juntas_geojson.sh` | script referencia WFS | 649B | referencia | sí |
| `consumo/curl_wfs_ciudad_geojson.sh` | script referencia WFS | 649B | referencia | sí |
| `consumo/curl_sparql_limit10.sh` | script referencia SPARQL | 435B | referencia | sí |
| `consumo/curl_sparql_limit10_no_accept.sh` | script referencia SPARQL | 400B | referencia | sí |
| `consumo/curl_sparql_limit10_format_mime.sh` | script referencia SPARQL | 468B | referencia | sí |
| `consumo/curl_sparql_limit10_format_json.sh` | script referencia SPARQL | 441B | referencia | sí |
| `consumo/curl_sparql_limit10_output_json.sh` | script referencia SPARQL | 441B | referencia | sí |
| `consumo/curl_sparql_grafo_emisiones_pending.sh` | script referencia SPARQL (pending) | 725B | referencia | sí |
| `consumo/test_sparql_format_variants.sh` | script referencia/test | 2.3K | referencia | sí |

Todos los curls escriben en `OUT_DIR` por defecto:
- WFS y SPARQL operativo → `data/real/consumo/responses`
- variantes SPARQL → `data/real/consumo/responses/sparql_format_tests`

### `data/real/ingesta/`

| path | tipo probable | tamaño | origen | versionar |
|------|---------------|--------|--------|-----------|
| `ingesta/BBDD_Residencial_2021.csv` | fuente real CSV municipal | 4.3M | fuente | **decisión pendiente** (tamaño) |

### Raíz `data/real/`

| path | tipo probable | tamaño | origen | versionar |
|------|---------------|--------|--------|-----------|
| `README.md` | documentación | 920B | fuente | sí |

### `data/real/consumo/responses/` (generado, ignorado)

| path | tipo | tamaño | origen | versionar |
|------|------|--------|--------|-----------|
| `responses/emisiones_sparql_limit10.json` | respuesta JSON | 2.9K | generado | no |
| `responses/emisiones_wfs_ciudad_geojson.json` | respuesta GeoJSON | 2.3M | generado | no |
| `responses/emisiones_wfs_juntas_geojson.json` | respuesta GeoJSON | 125K | generado | no |
| `responses/sparql_format_tests/sparql_format_json.response` | respuesta test | 2.9K | generado | no |
| `responses/sparql_format_tests/sparql_format_mime.response` | respuesta test | 2.9K | generado | no |
| `responses/sparql_format_tests/sparql_no_accept.response` | respuesta test | 3.4K | generado | no |
| `responses/sparql_format_tests/sparql_output_json.response` | respuesta test | 2.9K | generado | no |

**Nota:** `data/real/consumo/responses/` está ignorado por `.gitignore` y no debe entrar en Git.

### Propuesta futura (no aplicada)

Organizar curls en `data/real/consumo/wfs/` (2 scripts) y `data/real/consumo/sparql/` (6 scripts). Implicaría actualizar rutas en `test_sparql_format_variants.sh` y variables `OUT_DIR` de cada curl.

---

## 5. Inventario de scripts

### `scripts/` — core_automation / phase_script

| path | fase | descripción breve |
|------|------|-------------------|
| `phase0_context_smoke.sh` | 0 | Contextualización y smoke test (JWT + assets/request) |
| `phase1_provider_publish.sh` | 1 | Publicación asset HttpData (B1) |
| `phase1b_provider_upload_file.sh` | 1b | Upload fichero local a InesDataStore (B2) |
| `phase2_consumer_negotiate.sh` | 2 | Negociación contrato consumer |
| `phase3_transfer_edr.sh` | 3 | Transferencia EDR HttpData (B1) |
| `phase3b_inesdata_transfer.sh` | 3b | Transferencia AmazonS3-PUSH (B2) |
| `phase4_save_download.sh` | 4 | Descarga asset HttpData |
| `phase4b_consumer_storage_fetch.sh` | 4b | Descarga desde MinIO consumer |

### `scripts/` — library

| path | rol |
|------|-----|
| `lib_common.sh` | Funciones compartidas (curl, jq, evidencias, env) |

### `scripts/` — documentation

| path | rol |
|------|-----|
| `scripts/README.md` | Documentación técnica de uso |

### Raíz — connector/env exports

| path | clasificación | tracked | notas |
|------|---------------|---------|-------|
| `endpoints.sh` | connector/env export | sí | Mapa de endpoints Management API |
| `export_dataspace.sh` | connector/env export | sí | Variables dataspace |
| `export_provider.sh` | connector/env export | sí | **Contenido sensible — no documentado** |
| `export_consumer.sh` | connector/env export | sí | **Contenido sensible — no documentado** |
| `export_suffix.sh` | connector/env export | sí | SUFFIX de ejecución |

### Diagnóstico ad-hoc

**Confirmado:** no hay scripts de diagnóstico ad-hoc dentro de `scripts/`.

La lógica de diagnóstico está embebida en fases (`PHASE1_DEBUG`, funciones `_phase3_write_edr_diagnostics`, `_phase4b_mc_ls_diagnostic`). Los scripts de prueba SPARQL viven en `data/real/consumo/`. Los diagnósticos puntuales de ejecución deben permanecer en `evidencias/runs/<SUFFIX>/diagnostics/`.

---

## 6. Runtime/generated y backups

### Resumen por patrón

| patrón | clasificación | tracked | ignorado | conteo aprox. |
|--------|---------------|---------|----------|---------------|
| `phase*_env.sh` (raíz) | runtime_env | no | sí (`.gitignore:7`) | 6 |
| `phase*_env.sh.bak.*` (raíz) | runtime_backup | no | sí (`.gitignore:8`) | 15 |
| `evidencias/runs/**/phase*_env.sh` | runtime_env | no | sí (`evidencias/runs/`) | 37 |
| `evidencias/runs/**/21_transfer_final_state.sensitive.json` | sensitive_runtime | no | sí | 2 |
| `*.secret.json` | sensitive_runtime | — | sí | 0 encontrados |

**Totales encontrados:** 43 `phase*_env.sh`, 17 `phase*_env.sh.bak*`, 2 `*.sensitive.json`.

### Ficheros en raíz (runtime, ignorados)

| path | clasificación | tracked | ignorado |
|------|---------------|---------|----------|
| `phase0_env.sh` | runtime_env | no | `.gitignore:7:phase*_env.sh` |
| `phase1_env.sh` | runtime_env | no | idem |
| `phase1b_env.sh` | runtime_env | no | idem |
| `phase2_env.sh` | runtime_env | no | idem |
| `phase3_env.sh` | runtime_env | no | idem |
| `phase3b_env.sh` | runtime_env | no | idem |
| `phase0_env.sh.bak.1781856077` | runtime_backup | no | `.gitignore:8:phase*_env.sh.bak.*` |
| `phase0_env.sh.bak.1781856503` | runtime_backup | no | idem |
| `phase0_env.sh.bak.1781856547` | runtime_backup | no | idem |
| `phase0_env.sh.bak.1781857353` | runtime_backup | no | idem |
| `phase1_env.sh.bak.1781856086` | runtime_backup | no | idem |
| `phase1_env.sh.bak.1781856512` | runtime_backup | no | idem |
| `phase1_env.sh.bak.1781856558` | runtime_backup | no | idem |
| `phase1_env.sh.bak.1781857370` | runtime_backup | no | idem |
| `phase1b_env.sh.bak.1781856558` | runtime_backup | no | idem |
| `phase2_env.sh.bak.1781856095` | runtime_backup | no | idem |
| `phase2_env.sh.bak.1781856522` | runtime_backup | no | idem |
| `phase2_env.sh.bak.1781856567` | runtime_backup | no | idem |
| `phase2_env.sh.bak.1781857380` | runtime_backup | no | idem |
| `phase3_env.sh.bak.1781856111` | runtime_backup | no | idem |
| `phase3_env.sh.bak.1781856530` | runtime_backup | no | idem |
| `phase3_env.sh.bak.1781857388` | runtime_backup | no | idem |
| `phase3b_env.sh.bak.1781856571` | runtime_backup | no | idem |

### Ficheros sensibles en evidencias (solo metadatos)

| path | clasificación | tracked | ignorado |
|------|---------------|---------|----------|
| `evidencias/runs/1781784087/phase3b/21_transfer_final_state.sensitive.json` | sensitive_runtime | no | `evidencias/runs/` |
| `evidencias/runs/1781856546/phase3b/21_transfer_final_state.sensitive.json` | sensitive_runtime | no | idem |

**Contenido no incluido** (JWTs, credenciales, etc.).

### Runs de evidencias (SUFFIX detectados)

`1781775656`, `1781781445`, `1781781684`, `1781781894`, `1781781997`, `1781782673`, `1781784087`, `1781856076`, `1781856502`, `1781856546`, `1781857352`

---

## 7. Revisión de .gitignore

### Contenido actual

```gitignore
phase*_env.sh.bak.*
evidencias/runs/*/phase*_env.sh.bak.*
evidencias/runs/*/phase3b/*sensitive*.json
evidencias/runs/*/phase3b/*secret*.json

# Local generated env files
phase*_env.sh
phase*_env.sh.bak.*

# Runtime evidence / downloaded data
evidencias/runs/
downloads/

# Sensitive runtime artifacts
*.sensitive.json
*.secret.json
evidencias/runs/*/phase3b/*sensitive*.json
evidencias/runs/*/phase3b/*secret*.json

# Local/system
.DS_Store
.env
data/real/consumo/responses/
```

### Matriz de cobertura

| patrón requerido | estado | regla |
|------------------|--------|-------|
| `phase*_env.sh` | Cubierto | línea 7 |
| `phase*_env.sh.bak*` | Cubierto con duplicados | líneas 1, 2, 8 |
| `*.sensitive.json` | Cubierto con duplicados | líneas 15, 17 |
| `*.secret.json` | Cubierto con duplicados | líneas 16, 18 |
| `evidencias/runs/` | Cubierto | línea 11 |
| `downloads/` | Cubierto | línea 12 |
| `data/real/consumo/responses/` | Cubierto (unstaged) | línea 23 |
| `.DS_Store` | Cubierto | línea 21 |
| `.env` | Cubierto | línea 22 |

### Propuestas (no aplicadas)

- Eliminar duplicados de `phase*_env.sh.bak.*` (aparece en líneas 1, 2 y 8).
- Simplificar reglas sensitive si están duplicadas (líneas 3–4 vs 17–18; línea 15 vs 17).
- Valorar ignorar `data/real/ingesta/*.csv` si el CSV real de 4.3M no debe versionarse.
- Considerar `**/.DS_Store` para cubrir subdirectorios explícitamente (opcional; `.DS_Store` ya funciona en la práctica).

---

## 8. Referencias internas detectadas

Búsqueda: rutas `asset_configs/*`, `data/real/*` en el repo (excl. `.git`, `evidencias`, `downloads`, `responses`).

| archivo | referencias encontradas | impacto si se reorganiza |
|---------|-------------------------|--------------------------|
| `README.md` | `asset_configs/http_jsonplaceholder_todos.json`, `asset_configs/upload/ingesta_csv_empresa_demo.json`, `data/real/consumo/README.md`, `asset_configs/real/` | Alto — ejemplos CLI y estructura documentada |
| `scripts/README.md` | `asset_configs/http_jsonplaceholder_todos.json`, `asset_configs/examples/*`, `asset_configs/upload/*`, `asset_configs/real/*`, `data/real/consumo/` | Alto — comandos copy/cp, ejemplos B1/B2 reales |
| `scripts/phase1b_provider_upload_file.sh` | `asset_configs/upload/ingesta_csv_empresa_demo.json` (comentarios + mensaje error) | Medio — path demo B2 hardcodeado en docs inline |
| `data/real/README.md` | `asset_configs/real/*` (5 configs), `data/real/consumo/`, `data/real/ingesta/BBDD_Residencial_2021.csv` | Alto — índice de configs reales |
| `data/real/consumo/README.md` | `asset_configs/real/*` (5 configs) | Alto — mapeo config ↔ curl |
| `asset_configs/real/ingesta_bbdd_residencial_2021_csv.json` | `local_file`: `data/real/ingesta/BBDD_Residencial_2021.csv` | Medio — solo si mueve ingesta |
| `data/real/consumo/curl_wfs_*.sh` (2) | `OUT_DIR=data/real/consumo/responses` | Bajo — solo si mueve responses o subcarpetas |
| `data/real/consumo/curl_sparql_*.sh` (5) | `OUT_DIR=data/real/consumo/responses` o `…/sparql_format_tests` | Medio — si reorganiza wfs/sparql |
| `data/real/consumo/test_sparql_format_variants.sh` | rutas a 4 curls + `OUT_DIR` | Alto — referencias cruzadas entre scripts |
| `.gitignore` | `data/real/consumo/responses/` | Bajo — actualizar si cambia path responses |

**Sin referencias detectadas:** `asset_configs/test_csv_public.json`.

**No referenciado:** `data/real/Ingesta` ni `data/real/Consumo` (mayúsculas) — no existen como rutas separadas.

---

## 9. Problemas detectados

1. **Mezcla de configs demo, reales y ejemplos** — demos HTTP en raíz de `asset_configs/`, plantillas en `examples/`, reales en `real/` plano, demo B2 en `upload/`.
2. **`asset_configs/real/` plano** — sin separación `consumo/` vs `ingesta/`.
3. **Falta separación WFS/SPARQL** dentro de consumo (tanto configs como curls).
4. **`asset_configs/upload/` ambiguo** — contiene solo demo B2; el nombre sugiere carpeta general de uploads.
5. **Demos en raíz** — `http_jsonplaceholder_todos.json` y `test_csv_public.json` no están en subcarpeta `demo/`.
6. **`test_csv_public.json` huérfano** — no referenciado en README ni scripts.
7. **Runtime en raíz** — 6 `phase*_env.sh` y 15 backups `.bak.*` generados localmente (ignorados, pero presentes en disco).
8. **`data/real/consumo/responses/` generado** — debe seguir ignorado; incluye respuestas de hasta 2.3M.
9. **CSV real 4.3M untracked** — requiere decisión: versionar en Git, Git LFS, o documentar obtención externa + `.gitignore`.
10. **Reorganización rompería rutas** — READMEs, comandos CLI, `local_file` en configs B2, `OUT_DIR` en curls y `test_sparql_format_variants.sh`.
11. **Duplicado demo B2** — `upload/ingesta_csv_empresa_demo.json` ≡ `examples/ingesta_csv_upload.example.json`.
12. **`.gitignore` con entradas duplicadas** — `phase*_env.sh.bak.*` y reglas sensitive repetidas.
13. **Cambios pendientes sin commit** — `.gitignore`, `README.md`, `scripts/README.md` modificados; `asset_configs/real/` y `data/real/` sin trackear.

---

## 10. Propuesta preliminar de estructura objetivo

### `asset_configs/`

```text
asset_configs/
  examples/
    emisiones_wfs.example.json
    emisiones_sparql.example.json
    emisiones_csv.example.json
    emisiones_wfs_gml.example.json
    ingesta_excel.example.json
    ingesta_csv_upload.example.json

  demo/
    http/
      http_jsonplaceholder_todos.json
      test_csv_public.json
    upload/
      ingesta_csv_empresa_demo.json

  real/
    consumo/
      wfs/
        emisiones_wfs_juntas_geojson.json
        emisiones_wfs_ciudad_geojson.json
      sparql/
        emisiones_sparql_limit10.json
        emisiones_sparql_limit10_format_json.json
        emisiones_sparql_grafo_emisiones_pending.json
    ingesta/
      ingesta_bbdd_residencial_2021_csv.json
      ingesta_api_tentativa.pending.json
```

### `data/real/`

```text
data/
  real/
    consumo/
      wfs/
        curl_wfs_juntas_geojson.sh
        curl_wfs_ciudad_geojson.sh
      sparql/
        curl_sparql_limit10.sh
        curl_sparql_limit10_no_accept.sh
        curl_sparql_limit10_format_mime.sh
        curl_sparql_limit10_format_json.sh
        curl_sparql_limit10_output_json.sh
        curl_sparql_grafo_emisiones_pending.sh
        test_sparql_format_variants.sh
      README.md
    ingesta/
      BBDD_Residencial_2021.csv
    README.md
```

### Pros

- Separación clara real / demo / examples.
- Separación consumo / ingesta.
- Separación WFS / SPARQL.
- Alinea asset configs con curls de referencia.
- Facilita documentar talleres y ejecuciones por tipo de asset.

### Contras

- Requiere actualizar muchas rutas (ver sección 8).
- Puede romper comandos existentes si no se hace con cuidado.
- Hay que decidir si mantener compatibilidad con `asset_configs/upload/` (alias, symlink o periodo de transición).
- Hay que decidir si versionar el CSV real de 4.3M.

### Rutas a actualizar si se adopta

- `README.md`, `scripts/README.md`
- `scripts/phase1b_provider_upload_file.sh` (comentarios/ejemplos)
- `data/real/README.md`, `data/real/consumo/README.md`
- `asset_configs/real/ingesta_bbdd_residencial_2021_csv.json` (`local_file` — solo si mueve ingesta)
- Todos los scripts curl y `test_sparql_format_variants.sh`
- Comandos `ASSET_CONFIG` / `ASSET_UPLOAD_CONFIG` documentados
- Posiblemente `.gitignore` si cambia path de `responses/`

---

## 11. Recomendaciones para plan de limpieza

Acciones candidatas; **ninguna ejecutada en este inventario**.

### Fase 1 — Congelar estado actual

- Commit del inventario (`docs/repo_inventory.md`) y de los cambios pendientes en docs (`.gitignore`, `README.md`, `scripts/README.md`).
- Decidir política para CSV real: versionar, LFS, o externalizar + ignorar.
- Decidir qué entra en Git de `asset_configs/real/` y `data/real/` (configs + curls sí; responses no).

### Fase 2 — Reorganizar asset_configs

- Crear `demo/http/` y `demo/upload/`.
- Mover demos desde raíz y `upload/` a `demo/`.
- Crear `real/consumo/wfs/`, `real/consumo/sparql/`, `real/ingesta/`.
- Mover configs reales a subcarpetas correspondientes.
- Resolver duplicado `upload/ingesta_csv_empresa_demo.json` vs `examples/ingesta_csv_upload.example.json`.
- Actualizar READMEs y comandos documentados.

### Fase 3 — Reorganizar data/real/consumo

- Crear `consumo/wfs/` y `consumo/sparql/`.
- Mover scripts curl.
- Actualizar `OUT_DIR`, rutas en `test_sparql_format_variants.sh` y READMEs.

### Fase 4 — Limpieza runtime

- Confirmar y simplificar `.gitignore` (eliminar duplicados).
- Eliminar localmente backups `.bak.*` en raíz si se decide (opcional; ya ignorados).
- Verificar que no se versionan `phase*_env.sh`, responses ni artefactos sensibles.

### Fase 5 — Validación post-limpieza

- `jq empty asset_configs/**/*.json` — validar JSON.
- `grep` de rutas antiguas — buscar referencias rotas.
- Ejecutar smoke B1 mínimo (JSONPlaceholder o WFS juntas) solo si procede tras reorganización.

---

*Fin del inventario.*
