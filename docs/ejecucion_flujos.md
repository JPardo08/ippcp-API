# Ejecución de flujos IPPCP

Esta guía explica cómo ejecutar los tres flujos validados del dataspace IPPCP actual. Está pensada para partir de cero.

No uses `flujos/test3/` para estas ejecuciones. `flujos/test3/` es histórico de pruebas. La operación actual se hace con `flujos/ippcp/`.

## Preparación común

Clona el repositorio compartible:

```bash
git clone https://github.com/JPardo08/ippcp-API.git
cd ippcp-API
```

Comprueba herramientas:

```bash
command -v curl
command -v jq
command -v python3
/usr/local/bin/bash --version
```

Si Bash está en otra ruta:

```bash
/opt/homebrew/bin/bash --version
```

En Linux o WSL:

```bash
bash --version
which bash
```

Define la ruta de Bash:

```bash
export BASH_BIN=/usr/local/bin/bash
```

Si tu Bash moderno está en `/opt/homebrew/bin/bash`:

```bash
export BASH_BIN=/opt/homebrew/bin/bash
```

Para el flujo de ingesta B2 instala `mc`:

```bash
brew install minio/stable/mc
```

Prepara usuarios locales sin OTP. Para ingesta:

```bash
cp flujos/ippcp/ingesta/user_provider.example.sh flujos/ippcp/ingesta/user_provider.sh
cp flujos/ippcp/ingesta/user_consumer.example.sh flujos/ippcp/ingesta/user_consumer.sh
```

Edita `flujos/ippcp/ingesta/user_provider.sh` y `flujos/ippcp/ingesta/user_consumer.sh`. Usa usuarios técnicos API sin OTP.

Para consumo:

```bash
cp flujos/ippcp/consumo/user_provider.example.sh flujos/ippcp/consumo/user_provider.sh
cp flujos/ippcp/consumo/user_consumer.example.sh flujos/ippcp/consumo/user_consumer.sh
```

Edita `flujos/ippcp/consumo/user_provider.sh` y `flujos/ippcp/consumo/user_consumer.sh`. Usa usuarios técnicos API sin OTP.

Valida el dataspace sin imprimir secretos:

```bash
source ./flujos/ippcp/export_dataspace.sh
echo "DS_NAME=$DS_NAME"
echo "DS_DOMAIN=$DS_DOMAIN"
echo "KEYCLOAK_URL=$KEYCLOAK_URL"
echo "KC_CLIENT=$KC_CLIENT"
```

Salida esperada:

```text
DS_NAME=ippcp
```

Comprueba DNS/red antes de lanzar fases:

```bash
nslookup conn-company-ippcp.ds.inesdata-project.eu
nslookup conn-citycouncil-ippcp.ds.inesdata-project.eu
```

Si aparece `Could not resolve host` durante `phase0`, revisa DNS, VPN o `/etc/hosts` antes de seguir. `phase0_env.sh` solo se genera si `phase0` termina correctamente.

## Flujo 1: asset de ingesta / Excel-CSV

### Objetivo

Publicar un fichero local de ingesta como asset `InesDataStore`, negociar el acceso desde el consumer y comprobar que el fichero llega al almacenamiento del consumer.

En la validación IPPCP actual el fichero real configurado es:

```text
data/real/ingesta/BBDD_Residencial_2021.csv
```

Ese fichero es local y no se versiona. Debe existir antes de lanzar el flujo.

### Configuración previa

Datasource y flujo:

```text
flujos/ippcp/export_dataspace.sh
flujos/ippcp/ingesta/
```

Roles:

```text
provider = conn-company-ippcp
consumer = conn-citycouncil-ippcp
```

Asset config:

```text
asset_configs/real/ingesta/ingesta_bbdd_residencial_2021_csv.json
```

Scripts usados:

```text
scripts/phase0_context_smoke.sh
scripts/phase1b_provider_upload_file.sh
scripts/phase2_consumer_negotiate.sh
scripts/phase3b_inesdata_transfer.sh
scripts/phase4b_consumer_storage_fetch.sh
```

Fases:

```text
phase0 -> phase1b -> phase2 -> phase3b -> phase4b
```

### Comandos completos

Empieza con una ejecución limpia:

```bash
export BASH_BIN=/usr/local/bin/bash
unset IPPCP_DATASPACE_FILE IPPCP_DATASPACE_DIR IPPCP_DATASPACE
unset SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL CD_ID VOCAB_ID ACCESS_POLICY_ID CONTRACT_POLICY_ID

export IPPCP_FLOW=ingesta
export IPPCP_FLOW_DIR="$PWD/flujos/ippcp/ingesta"
export IPPCP_DATASPACE_DIR="$PWD/flujos/ippcp"

$BASH_BIN scripts/phase0_context_smoke.sh
```

Si `phase0` termina con `Fase 0 OK`, publica el asset de ingesta:

```bash
source runtime/env/latest/phase0_env.sh

ASSET_UPLOAD_CONFIG=asset_configs/real/ingesta/ingesta_bbdd_residencial_2021_csv.json $BASH_BIN scripts/phase1b_provider_upload_file.sh
```

Si `phase1b` termina con `Fase 1b OK`, negocia el contrato:

```bash
source runtime/env/latest/phase1b_env.sh
$BASH_BIN scripts/phase2_consumer_negotiate.sh
```

Si `phase2` termina con `Fase 2 OK`, lanza la transferencia B2:

```bash
source runtime/env/latest/phase2_env.sh
$BASH_BIN scripts/phase3b_inesdata_transfer.sh
```

Si `phase3b` termina con `Fase 3b OK`, descarga desde MinIO consumer:

```bash
source runtime/env/latest/phase3b_env.sh
$BASH_BIN scripts/phase4b_consumer_storage_fetch.sh
```

### IDs esperados

Durante la ejecución aparecerán valores como:

```text
SUFFIX=<SUFFIX>
ASSET_ID=ippcp_ingesta_bbdd_residencial_2021_csv-<SUFFIX>
ACCESS_POLICY_ID=access-<SUFFIX>
CONTRACT_POLICY_ID=contract-<SUFFIX>
CD_ID=cd-<SUFFIX>
NEG_ID=<negotiation-id>
AGREEMENT_ID=<agreement-id>
TRANSFER_ID=<transfer-process-id>
```

En el run validado de IPPCP:

```text
SUFFIX=1783070399
ASSET_ID=ippcp_ingesta_bbdd_residencial_2021_csv-1783070399
```

### Evidencias generadas

Evidencias por fase:

```text
evidencias/runs/<SUFFIX>/phase0/
evidencias/runs/<SUFFIX>/phase1b/
evidencias/runs/<SUFFIX>/phase2/
evidencias/runs/<SUFFIX>/phase3b/
evidencias/runs/<SUFFIX>/phase4b/
evidencias/runs/<SUFFIX>/summary.json
```

Env files:

```text
runtime/env/latest/phase0_env.sh
runtime/env/latest/phase1b_env.sh
runtime/env/latest/phase2_env.sh
runtime/env/latest/phase3b_env.sh
```

Descarga verificada:

```text
downloads/assets/<ASSET_ID>/latest.csv
downloads/manifests/<ASSET_ID>/latest.manifest.json
```

### Comprobación final

```bash
echo "T1 SUFFIX=$SUFFIX"
echo "ASSET_ID=$ASSET_ID"
ls -lh "downloads/assets/$ASSET_ID/latest.${ASSET_EXTENSION:-csv}"
jq . "downloads/manifests/$ASSET_ID/latest.manifest.json"
```

El manifest debe incluir:

```text
storage_mode=inesdatastore
transfer_type=AmazonS3-PUSH
source=consumer_minio
bytes=<numero>
sha256=<hash>
```

`consumer_transfer_state=STARTED` puede ser aceptable si `phase4b` termina OK y hay `bytes` y `sha256`.

### Errores frecuentes

- `No se pudo obtener JWT`: usuario con OTP, credenciales incorrectas o realm incorrecto.
- `STORAGE_MODE debe ser inesdatastore`: se cargó un env antiguo o se usó `phase1` en vez de `phase1b`.
- `ASSET_UPLOAD_CONFIG no encontrado`: ruta de config incorrecta.
- `local_file no encontrado`: falta `data/real/ingesta/BBDD_Residencial_2021.csv`.
- Error de `mc`: falta cliente MinIO o no se recibieron credenciales S3 válidas en `phase3b`.

## Flujo 2: asset HTTP WFS

### Objetivo

Publicar un recurso HTTP tipo WFS como asset `HttpData`, negociar el acceso desde el consumer y descargar el contenido mediante EDR.

### Configuración previa

Datasource y flujo:

```text
flujos/ippcp/export_dataspace.sh
flujos/ippcp/consumo/
```

Roles:

```text
provider = conn-citycouncil-ippcp
consumer = conn-company-ippcp
```

Asset config:

```text
asset_configs/real/consumo/wfs/emisiones_wfs_ciudad_geojson.json
```

El endpoint WFS está definido en el JSON de configuración del asset. Si se prepara una versión para terceros y no se quiere publicar una URL concreta, documenta el campo como:

```text
base_url=<PROVIDER_WFS_URL>
```

Scripts usados:

```text
scripts/phase0_context_smoke.sh
scripts/phase1_provider_publish.sh
scripts/phase2_consumer_negotiate.sh
scripts/phase3_transfer_edr.sh
scripts/phase4_save_download.sh
```

Fases:

```text
phase0 -> phase1 -> phase2 -> phase3 -> phase4
```

### Comandos completos

Empieza con una ejecución limpia:

```bash
export BASH_BIN=/usr/local/bin/bash
unset IPPCP_DATASPACE_FILE IPPCP_DATASPACE_DIR IPPCP_DATASPACE
unset SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL CD_ID VOCAB_ID ACCESS_POLICY_ID CONTRACT_POLICY_ID

export IPPCP_FLOW=consumo
export IPPCP_FLOW_DIR="$PWD/flujos/ippcp/consumo"
export IPPCP_DATASPACE_DIR="$PWD/flujos/ippcp"

$BASH_BIN scripts/phase0_context_smoke.sh
```

Si `phase0` termina con `Fase 0 OK`, publica el asset WFS:

```bash
source runtime/env/latest/phase0_env.sh

ASSET_CONFIG=asset_configs/real/consumo/wfs/emisiones_wfs_ciudad_geojson.json $BASH_BIN scripts/phase1_provider_publish.sh
```

Si el taller decide usar la variante WFS de juntas, sustituye el config por:

```bash
ASSET_CONFIG=asset_configs/real/consumo/wfs/emisiones_wfs_juntas_geojson.json $BASH_BIN scripts/phase1_provider_publish.sh
```

Si `phase1` termina con `Fase 1 OK`, negocia el contrato:

```bash
source runtime/env/latest/phase1_env.sh
$BASH_BIN scripts/phase2_consumer_negotiate.sh
```

Si `phase2` termina con `Fase 2 OK`, lanza transferencia y consumo por EDR:

```bash
source runtime/env/latest/phase2_env.sh
$BASH_BIN scripts/phase3_transfer_edr.sh
```

Si `phase3` termina con `Fase 3 OK`, guarda la descarga:

```bash
source runtime/env/latest/phase3_env.sh
$BASH_BIN scripts/phase4_save_download.sh
```

### IDs esperados

Durante la ejecución aparecerán valores como:

```text
SUFFIX=<SUFFIX>
ASSET_ID=ippcp_emisiones_wfs_ciudad_geojson-<SUFFIX>
ACCESS_POLICY_ID=access-<SUFFIX>
CONTRACT_POLICY_ID=contract-<SUFFIX>
CD_ID=cd-<SUFFIX>
NEG_ID=<negotiation-id>
AGREEMENT_ID=<agreement-id>
TRANSFER_ID=<transfer-process-id>
EDR_URL=<edr-public-url>
```

En el run validado de IPPCP:

```text
SUFFIX=1783070513
ASSET_ID=ippcp_emisiones_wfs_ciudad_geojson-1783070513
```

### Evidencias generadas

Evidencias por fase:

```text
evidencias/runs/<SUFFIX>/phase0/
evidencias/runs/<SUFFIX>/phase1/
evidencias/runs/<SUFFIX>/phase2/
evidencias/runs/<SUFFIX>/phase3/
evidencias/runs/<SUFFIX>/phase4/
evidencias/runs/<SUFFIX>/summary.json
```

Env files:

```text
runtime/env/latest/phase0_env.sh
runtime/env/latest/phase1_env.sh
runtime/env/latest/phase2_env.sh
runtime/env/latest/phase3_env.sh
```

Descarga verificada:

```text
downloads/assets/<ASSET_ID>/latest.json
downloads/manifests/<ASSET_ID>/latest.manifest.json
```

### Comprobación final

```bash
echo "T2 SUFFIX=$SUFFIX"
echo "ASSET_ID=$ASSET_ID"
ls -lh "downloads/assets/$ASSET_ID/latest.${ASSET_EXTENSION:-json}"
jq . "downloads/manifests/$ASSET_ID/latest.manifest.json"
```

El manifest debe incluir:

```text
content_kind=json
extension=json
bytes=<numero>
sha256=<hash>
```

`transfer_state=STARTED` puede ser aceptable si `phase3` consumió datos y `phase4` guardó descarga con `sha256`.

### Errores frecuentes

- `No se pudo obtener JWT`: usuario con OTP, credenciales incorrectas o realm incorrecto.
- `ASSET_CONFIG no encontrado`: ruta incorrecta.
- `ASSET_CONFIG: type debe ser HttpData`: se usó una config B2 en `phase1`.
- `HTTP 403` en una variante de autorización: puede no bloquear si otra variante devuelve `HTTP 200` y `phase3` termina OK.
- Descarga vacía: revisar endpoint WFS, permisos y accesibilidad desde el dataplane.

## Flujo 3: asset HTTP SPARQL

### Objetivo

Publicar un recurso HTTP tipo SPARQL como asset `HttpData`, negociar el acceso desde el consumer y descargar el resultado JSON mediante EDR.

### Configuración previa

Datasource y flujo:

```text
flujos/ippcp/export_dataspace.sh
flujos/ippcp/consumo/
```

Roles:

```text
provider = conn-citycouncil-ippcp
consumer = conn-company-ippcp
```

Asset config:

```text
asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json
```

El endpoint SPARQL está definido en el JSON de configuración del asset. Si se prepara una versión para terceros y no se quiere publicar una URL concreta, documenta el campo como:

```text
base_url=<PROVIDER_SPARQL_URL>
```

Scripts usados:

```text
scripts/phase0_context_smoke.sh
scripts/phase1_provider_publish.sh
scripts/phase2_consumer_negotiate.sh
scripts/phase3_transfer_edr.sh
scripts/phase4_save_download.sh
```

Fases:

```text
phase0 -> phase1 -> phase2 -> phase3 -> phase4
```

### Comandos completos

Empieza con una ejecución limpia:

```bash
export BASH_BIN=/usr/local/bin/bash
unset IPPCP_DATASPACE_FILE IPPCP_DATASPACE_DIR IPPCP_DATASPACE
unset SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL CD_ID VOCAB_ID ACCESS_POLICY_ID CONTRACT_POLICY_ID

export IPPCP_FLOW=consumo
export IPPCP_FLOW_DIR="$PWD/flujos/ippcp/consumo"
export IPPCP_DATASPACE_DIR="$PWD/flujos/ippcp"

$BASH_BIN scripts/phase0_context_smoke.sh
```

Si `phase0` termina con `Fase 0 OK`, publica el asset SPARQL:

```bash
source runtime/env/latest/phase0_env.sh

ASSET_CONFIG=asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json $BASH_BIN scripts/phase1_provider_publish.sh
```

Si `phase1` termina con `Fase 1 OK`, negocia el contrato:

```bash
source runtime/env/latest/phase1_env.sh
$BASH_BIN scripts/phase2_consumer_negotiate.sh
```

Si `phase2` termina con `Fase 2 OK`, lanza transferencia y consumo por EDR:

```bash
source runtime/env/latest/phase2_env.sh
$BASH_BIN scripts/phase3_transfer_edr.sh
```

Si `phase3` termina con `Fase 3 OK`, guarda la descarga:

```bash
source runtime/env/latest/phase3_env.sh
$BASH_BIN scripts/phase4_save_download.sh
```

### IDs esperados

Durante la ejecución aparecerán valores como:

```text
SUFFIX=<SUFFIX>
ASSET_ID=ippcp_emisiones_sparql_limit10_format_json-<SUFFIX>
ACCESS_POLICY_ID=access-<SUFFIX>
CONTRACT_POLICY_ID=contract-<SUFFIX>
CD_ID=cd-<SUFFIX>
NEG_ID=<negotiation-id>
AGREEMENT_ID=<agreement-id>
TRANSFER_ID=<transfer-process-id>
EDR_URL=<edr-public-url>
```

En el run validado de IPPCP:

```text
SUFFIX=1783070583
ASSET_ID=ippcp_emisiones_sparql_limit10_format_json-1783070583
```

### Evidencias generadas

Evidencias por fase:

```text
evidencias/runs/<SUFFIX>/phase0/
evidencias/runs/<SUFFIX>/phase1/
evidencias/runs/<SUFFIX>/phase2/
evidencias/runs/<SUFFIX>/phase3/
evidencias/runs/<SUFFIX>/phase4/
evidencias/runs/<SUFFIX>/summary.json
```

Env files:

```text
runtime/env/latest/phase0_env.sh
runtime/env/latest/phase1_env.sh
runtime/env/latest/phase2_env.sh
runtime/env/latest/phase3_env.sh
```

Descarga verificada:

```text
downloads/assets/<ASSET_ID>/latest.json
downloads/manifests/<ASSET_ID>/latest.manifest.json
```

### Comprobación final

```bash
echo "T3 SUFFIX=$SUFFIX"
echo "ASSET_ID=$ASSET_ID"
ls -lh "downloads/assets/$ASSET_ID/latest.${ASSET_EXTENSION:-json}"
jq . "downloads/manifests/$ASSET_ID/latest.manifest.json"
```

El manifest debe incluir:

```text
content_kind=json
extension=json
bytes=<numero>
sha256=<hash>
```

`transfer_state=STARTED` puede ser aceptable si `phase3` consumió datos y `phase4` guardó descarga con `sha256`.

### Errores frecuentes

- `No se pudo obtener JWT`: usuario con OTP, credenciales incorrectas o realm incorrecto.
- Respuesta HTML/XML en vez de JSON: usar la config operativa con `format=application/sparql-results+json`.
- `ASSET_CONFIG no encontrado`: ruta incorrecta.
- `ASSET_CONFIG: content_kind=json requiere extension=json`: config incompatible.
- `HTTP 403` en una variante de autorización: puede no bloquear si otra variante devuelve `HTTP 200` y `phase3` termina OK.
- Descarga vacía: revisar consulta SPARQL, formato de respuesta y accesibilidad desde el dataplane.

## Revisión de resultados

Para cualquier flujo, revisa:

```bash
jq . "evidencias/runs/${SUFFIX}/summary.json"
```

Revisa descargas:

```bash
find "downloads/assets/$ASSET_ID" -maxdepth 1 -type f
find "downloads/manifests/$ASSET_ID" -maxdepth 1 -type f
```

No subas a Git `evidencias/runs/`, `downloads/assets/`, `downloads/manifests/` ni `runtime/env/latest/`.
