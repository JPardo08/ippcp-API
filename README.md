# IPPCP API Automation

Este repositorio contiene scripts y documentación para operar por API el espacio de datos / EdD de IPPCP sobre conectores INESData. La finalidad es poder ejecutar las operaciones principales sin depender de la interfaz gráfica.

El repositorio compartible para terceros será:

```bash
git clone https://github.com/JPardo08/ippcp-API.git
cd ippcp-API
```

La documentación operativa principal se centra en el dataspace actual validado `ippcp`, configurado en `flujos/ippcp/`. El dataspace `test3`, configurado en `flujos/test3/`, queda como histórico de pruebas y no debe confundirse con la operación actual de IPPCP.

## Qué Automatiza

Los scripts permiten ejecutar de forma reproducible:

- autenticación contra Keycloak;
- carga de configuración del dataspace;
- carga de configuración de provider y consumer;
- creación de assets;
- creación de políticas;
- creación de contract definitions;
- consulta de catálogo;
- negociación;
- obtención de agreement;
- transferencia;
- descarga o consumo del dato;
- generación de evidencias;
- generación de `summary.json`.

## Estado Actual

El EdD específico de IPPCP ya está levantado. El dataspace `ippcp` ha sido corregido, probado y validado mediante automatización API.

Se han probado correctamente tres assets reales:

- ingesta / Excel-CSV mediante `InesDataStore`;
- HTTP WFS mediante `HttpData`;
- HTTP SPARQL mediante `HttpData`.

Runs IPPCP validados:

```text
T1 ingesta / Excel-CSV: 1783070399
T2 HTTP WFS:            1783070513
T3 HTTP SPARQL:         1783070583
```

Estos runs generan evidencias locales bajo `evidencias/runs/<SUFFIX>/` y descargas verificadas bajo `downloads/`.

## Requisitos Previos

Antes de ejecutar los flujos hace falta:

- terminal Unix-like;
- Bash 4.3 o superior;
- `curl`;
- `jq`;
- `python3` recomendado;
- cliente MinIO `mc` para el flujo de ingesta B2;
- acceso de red a las URLs públicas del EdD;
- usuario técnico provider con permisos en el conector provider;
- usuario técnico consumer con permisos en el conector consumer;
- cliente válido en Keycloak para obtener tokens;
- configuración correcta de dataspace, provider, consumer y endpoints.

En macOS puede haber dos rutas habituales de Bash moderno:

```bash
/usr/local/bin/bash --version
/opt/homebrew/bin/bash --version
```

Define una variable para no repetir la ruta:

```bash
export BASH_BIN=/usr/local/bin/bash
```

Si tu Bash moderno está en Apple Silicon/Homebrew moderno:

```bash
export BASH_BIN=/opt/homebrew/bin/bash
```

Para el flujo B2 de ingesta:

```bash
brew install minio/stable/mc
```

### Importante: Usuarios API Sin OTP

Los usuarios técnicos usados por los scripts API no deben tener OTP / MFA interactivo activado.

Motivo:

- los scripts necesitan pedir tokens de forma automática;
- el flujo de token usado por los scripts no puede responder a una pantalla interactiva de OTP;
- si Keycloak exige OTP, la obtención de token falla;
- la ejecución deja de ser reproducible;
- para usuarios de UI puede tener sentido usar OTP;
- para automatización API conviene usar usuarios técnicos separados, sin OTP, con permisos limitados y controlados.

Recomendaciones:

- usar un usuario técnico específico para provider;
- usar un usuario técnico específico para consumer;
- no reutilizar cuentas personales para automatización;
- no guardar contraseñas reales en documentación;
- no subir `user_provider.sh`, `user_consumer.sh`, `.env`, tokens ni secretos a Git.

## Estructura Real

La estructura actual no es plana. El dataspace y los flujos están anidados:

```text
ippcp-API/
  README.md
  .gitignore
  endpoints.sh
  export_suffix.sh

  flujos/
    ippcp/
      export_dataspace.sh
      ingesta/
        export_provider.sh
        export_consumer.sh
        user_provider.example.sh
        user_consumer.example.sh
        user_provider.sh          # local, no versionar
        user_consumer.sh          # local, no versionar
      consumo/
        export_provider.sh
        export_consumer.sh
        user_provider.example.sh
        user_consumer.example.sh
        user_provider.sh          # local, no versionar
        user_consumer.sh          # local, no versionar

    test3/
      export_dataspace.sh         # histórico / pruebas
      ingesta/
      consumo/

  scripts/
    lib_common.sh
    phase0_context_smoke.sh
    phase1_provider_publish.sh
    phase1b_provider_upload_file.sh
    phase2_consumer_negotiate.sh
    phase3_transfer_edr.sh
    phase3b_inesdata_transfer.sh
    phase4_save_download.sh
    phase4b_consumer_storage_fetch.sh

  asset_configs/
    real/
      ingesta/
      consumo/
        wfs/
        sparql/

  evidencias/
    runs/                         # generado localmente, no versionar

  runtime/
    env/
      latest/                     # generado localmente, no versionar
      backups/                    # generado localmente, no versionar

  downloads/
    assets/                       # generado localmente, no versionar
    manifests/                    # generado localmente, no versionar

  docs/
```

Nota histórica: documentación antigua puede mencionar `export_dataspace.sh` en la raíz o rutas planas como `flujos/ingesta` y `flujos/consumo`. Esa estructura era anterior. Para IPPCP actual se debe usar `flujos/ippcp/ingesta` y `flujos/ippcp/consumo`.

## Configuración Inicial

La configuración se carga en este orden conceptual:

```bash
source ./export_suffix.sh
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/<flujo>/export_provider.sh
source ./flujos/ippcp/<flujo>/export_consumer.sh
```

En la ejecución normal no hace falta cargar manualmente todos esos ficheros: `scripts/lib_common.sh` lo hace desde los scripts de fase. Aun así, entender el orden ayuda a diagnosticar errores.

Para ejecutar IPPCP se recomienda indicar siempre el flujo anidado:

```bash
export IPPCP_FLOW=ingesta
export IPPCP_FLOW_DIR="$PWD/flujos/ippcp/ingesta"
```

Para consumo:

```bash
export IPPCP_FLOW=consumo
export IPPCP_FLOW_DIR="$PWD/flujos/ippcp/consumo"
```

Más detalle:

- [Configuración](docs/configuracion.md)
- [Ejecución de flujos](docs/ejecucion_flujos.md)
- [Evidencias](docs/evidencias.md)
- [Problemas frecuentes](docs/troubleshooting.md)

## Ejecución Paso A Paso

### 1. Clonar El Repositorio Compartible

```bash
git clone https://github.com/JPardo08/ippcp-API.git
cd ippcp-API
```

### 2. Revisar Requisitos

```bash
command -v curl
command -v jq
command -v python3
/usr/local/bin/bash --version
```

Si usas Apple Silicon y Homebrew instaló Bash en otra ruta:

```bash
/opt/homebrew/bin/bash --version
```

### 3. Definir Bash

```bash
export BASH_BIN=/usr/local/bin/bash
```

Si corresponde:

```bash
export BASH_BIN=/opt/homebrew/bin/bash
```

### 4. Preparar Credenciales Locales

Para ingesta:

```bash
cp flujos/ippcp/ingesta/user_provider.example.sh flujos/ippcp/ingesta/user_provider.sh
cp flujos/ippcp/ingesta/user_consumer.example.sh flujos/ippcp/ingesta/user_consumer.sh
```

Edita `flujos/ippcp/ingesta/user_provider.sh` y `flujos/ippcp/ingesta/user_consumer.sh` localmente con usuarios técnicos sin OTP.

Para consumo:

```bash
cp flujos/ippcp/consumo/user_provider.example.sh flujos/ippcp/consumo/user_provider.sh
cp flujos/ippcp/consumo/user_consumer.example.sh flujos/ippcp/consumo/user_consumer.sh
```

Edita `flujos/ippcp/consumo/user_provider.sh` y `flujos/ippcp/consumo/user_consumer.sh` localmente con usuarios técnicos sin OTP.

### 5. Ejecutar Los Tres Flujos

Los comandos completos están en [Ejecución de flujos](docs/ejecucion_flujos.md).

Resumen:

- ingesta / Excel-CSV: `phase0 -> phase1b -> phase2 -> phase3b -> phase4b`;
- HTTP WFS: `phase0 -> phase1 -> phase2 -> phase3 -> phase4`;
- HTTP SPARQL: `phase0 -> phase1 -> phase2 -> phase3 -> phase4`.

## Flujos Soportados

### Flujo 1: Asset De Ingesta / Excel-CSV

Este flujo publica un fichero local como asset `InesDataStore`, negocia el contrato y verifica que el dato llega al storage del consumer.

Configuración operativa:

- dataspace: `flujos/ippcp/export_dataspace.sh`;
- flujo: `flujos/ippcp/ingesta/`;
- provider: `conn-company-ippcp`;
- consumer: `conn-citycouncil-ippcp`;
- config de asset: `asset_configs/real/ingesta/ingesta_bbdd_residencial_2021_csv.json`;
- fichero local requerido: `data/real/ingesta/BBDD_Residencial_2021.csv`.

Comandos completos: [Flujo 1 en docs/ejecucion_flujos.md](docs/ejecucion_flujos.md#flujo-1-asset-de-ingesta--excel-csv).

### Flujo 2: Asset HTTP WFS

Este flujo publica un endpoint HTTP WFS como asset `HttpData`, negocia el contrato y descarga el contenido consumido por EDR.

Configuración operativa:

- dataspace: `flujos/ippcp/export_dataspace.sh`;
- flujo: `flujos/ippcp/consumo/`;
- provider: `conn-citycouncil-ippcp`;
- consumer: `conn-company-ippcp`;
- config de asset: `asset_configs/real/consumo/wfs/emisiones_wfs_ciudad_geojson.json`.

Comandos completos: [Flujo 2 en docs/ejecucion_flujos.md](docs/ejecucion_flujos.md#flujo-2-asset-http-wfs).

### Flujo 3: Asset HTTP SPARQL

Este flujo publica un endpoint HTTP SPARQL como asset `HttpData`, negocia el contrato y descarga el resultado JSON consumido por EDR.

Configuración operativa:

- dataspace: `flujos/ippcp/export_dataspace.sh`;
- flujo: `flujos/ippcp/consumo/`;
- provider: `conn-citycouncil-ippcp`;
- consumer: `conn-company-ippcp`;
- config de asset: `asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json`.

Comandos completos: [Flujo 3 en docs/ejecucion_flujos.md](docs/ejecucion_flujos.md#flujo-3-asset-http-sparql).

## Evidencias Generadas

Cada ejecución genera un identificador `SUFFIX`. En este repositorio no se usa el nombre `run_id` ni `correlation_id`; el identificador práctico es `SUFFIX`.

Estructura principal:

```text
evidencias/runs/<SUFFIX>/
  phase0/
  phase1/
  phase1b/
  phase2/
  phase3/
  phase3b/
  phase4/
  phase4b/
  summary.json
```

Las descargas verificadas se guardan en:

```text
downloads/assets/<ASSET_ID>/latest.<extension>
downloads/manifests/<ASSET_ID>/latest.manifest.json
```

La entrega Excel/ZIP se genera con:

```text
tools/export_evidence_to_excel.py
tools/package_evidence_bundle.py
tools/evidence_export.tests.yaml
```

Más detalle: [Evidencias](docs/evidencias.md).

## Seguridad

No versionar:

```text
flujos/**/user_provider.sh
flujos/**/user_consumer.sh
.env
*.key
*.pem
*token*
*secret*
phase*_env.sh
runtime/env/latest/
runtime/env/backups/
evidencias/runs/
downloads/assets/
downloads/manifests/
reports/
```

Los scripts no deben guardar tokens completos en evidencias. Los JSON de claims solo incluyen metadatos seguros como `iat`, `exp`, `now` y `token_length`.

## Documentación Complementaria

- [Configuración](docs/configuracion.md)
- [Ejecución de flujos](docs/ejecucion_flujos.md)
- [Evidencias](docs/evidencias.md)
- [Problemas frecuentes](docs/troubleshooting.md)
- [Sincronización Notion](docs/notion_sync.md)
- [scripts/scripts_README.md](scripts/scripts_README.md)
- [tools/tools_README.md](tools/tools_README.md)
- [runtime/runtime_README.md](runtime/runtime_README.md)
- [downloads/downloads_README.md](downloads/downloads_README.md)
- [data/real/real_README.md](data/real/real_README.md)
- [flujos/ippcp/ingesta/ingesta_README.md](flujos/ippcp/ingesta/ingesta_README.md)
- [flujos/ippcp/consumo/consumo_README.md](flujos/ippcp/consumo/consumo_README.md)

## Histórico `test3`

`flujos/test3/` conserva configuración y documentación de pruebas históricas. Sirve como referencia interna de evolución, pero no es la configuración operativa actual de IPPCP.

Para operar el EdD de IPPCP validado se debe usar `flujos/ippcp/`.
