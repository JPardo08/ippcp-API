# Problemas Frecuentes

Esta guía ayuda a diagnosticar errores habituales al operar el EdD de IPPCP por API.

La configuración operativa actual está en `flujos/ippcp/`. `flujos/test3/` es histórico de pruebas.

## El Usuario API Tiene OTP Activado

### Síntoma

El script falla al obtener token:

```text
No se pudo obtener JWT para provider
No se pudo obtener JWT para consumer
```

Al probar con `curl`, Keycloak puede responder:

```json
{"error":"invalid_grant","error_description":"Invalid user credentials"}
```

### Causa

Los scripts usan un flujo automatizado de token. Si el usuario tiene OTP / MFA interactivo, Keycloak espera un segundo paso manual. El script no puede introducir ese OTP.

Para login por UI puede tener sentido usar OTP. Para automatización API no.

### Solución

Usa usuarios técnicos sin OTP:

- usuario técnico provider;
- usuario técnico consumer;
- permisos limitados;
- sin required actions pendientes;
- email verificado si Keycloak lo exige;
- sin `Configure OTP` pendiente.

No uses usuarios personales de UI para automatización.

## URL De Dataspace Incorrecta

### Síntoma

El script obtiene token de un realm antiguo, por ejemplo `test3`, pero llama a conectores `ippcp`.

Puede aparecer:

```text
HTTP 500
publicKey is null
JWT inválido
```

### Causa

Se cargó un `export_dataspace.sh` que no corresponde al flujo actual.

### Comprobación

```bash
source ./flujos/ippcp/export_dataspace.sh
echo "DS_NAME=$DS_NAME"
echo "KEYCLOAK_URL=$KEYCLOAK_URL"
echo "KC_CLIENT=$KC_CLIENT"
```

Debe salir:

```text
DS_NAME=ippcp
```

Comprueba el flujo:

```bash
echo "IPPCP_FLOW=$IPPCP_FLOW"
echo "IPPCP_FLOW_DIR=$IPPCP_FLOW_DIR"
```

Para ingesta IPPCP debe apuntar a:

```text
flujos/ippcp/ingesta
```

Para consumo IPPCP debe apuntar a:

```text
flujos/ippcp/consumo
```

## Provider Mal Configurado

### Síntomas

- `401` al llamar al Management API del provider;
- `403` al crear assets, policies o contract definitions;
- `404` en endpoints de Management API;
- asset no creado;
- policy no creada;
- contract definition no creada;
- endpoint HTTP del recurso no accesible.

### Comprobación

Para ingesta:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/ingesta/export_provider.sh
echo "PROVIDER=$PROVIDER"
echo "PROVIDER_BASE=$PROVIDER_BASE"
echo "PROVIDER_PROTOCOL=$PROVIDER_PROTOCOL"
```

Para consumo:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/consumo/export_provider.sh
echo "PROVIDER=$PROVIDER"
echo "PROVIDER_BASE=$PROVIDER_BASE"
echo "PROVIDER_PROTOCOL=$PROVIDER_PROTOCOL"
```

### Solución

- Verifica que el provider corresponde al flujo.
- Verifica que el usuario provider tiene rol del conector.
- Verifica que `DS_NAME=ippcp`.
- Ejecuta `phase0_context_smoke.sh` antes de publicar assets.
- Revisa el body `.json` y el status `.http` en `evidencias/runs/<SUFFIX>/phase1/` o `phase1b/`.

## Consumer Mal Configurado

### Síntomas

- catálogo remoto no accesible;
- negotiation no creada;
- agreement no encontrado;
- transfer fallida;
- token consumer equivocado;
- `401` o `403` en phase2 o phase3.

### Comprobación

Para ingesta:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/ingesta/export_consumer.sh
echo "CONSUMER=$CONSUMER"
echo "CONSUMER_BASE=$CONSUMER_BASE"
echo "CONSUMER_PROTOCOL=$CONSUMER_PROTOCOL"
```

Para consumo:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/consumo/export_consumer.sh
echo "CONSUMER=$CONSUMER"
echo "CONSUMER_BASE=$CONSUMER_BASE"
echo "CONSUMER_PROTOCOL=$CONSUMER_PROTOCOL"
```

### Solución

- Verifica que consumer y provider no están cruzados.
- Verifica que el usuario consumer tiene rol del conector.
- Verifica que estás cargando `flujos/ippcp/ingesta` para ingesta y `flujos/ippcp/consumo` para WFS/SPARQL.
- Revisa `evidencias/runs/<SUFFIX>/phase2/`.

## Token Caducado O Inválido

### Síntoma

Una fase que antes funcionaba empieza a devolver `401` o `403`.

### Causa

Los tokens expiran. Los scripts los renuevan por fase, pero si ejecutas comandos manuales puedes estar usando un token antiguo.

### Solución

Ejecuta la fase de nuevo con el env correcto:

```bash
source runtime/env/latest/phase0_env.sh
$BASH_BIN scripts/phase1_provider_publish.sh
```

Para validar un usuario sin imprimir tokens completos:

```bash
curl -sS -w '\nHTTP=%{http_code}\n' -X POST "$KEYCLOAK_URL/realms/$DS_NAME/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "client_id=$KC_CLIENT" \
  --data-urlencode "username=<USERNAME>" \
  --data-urlencode "password=<PASSWORD>" \
  --data-urlencode "scope=openid profile email"
```

No pegues tokens completos en documentación ni chats.

## Error Al Crear Asset

### Síntomas

- `phase1_provider_publish.sh` falla;
- `phase1b_provider_upload_file.sh` falla;
- `ASSET_CONFIG` inválido;
- `ASSET_UPLOAD_CONFIG` inválido;
- `HTTP 400`, `401`, `403`, `404` o `409`.

### Causas Posibles

- payload incompatible;
- endpoint Management API incorrecto;
- credenciales insuficientes;
- URL HTTP del recurso no accesible desde el provider/dataplane;
- datos obligatorios ausentes;
- asset ya existe para el mismo `SUFFIX`;
- se usó config B2 con `phase1_provider_publish.sh`;
- se usó config HTTP con `phase1b_provider_upload_file.sh`.

### Solución

Revisa el config:

```bash
jq . asset_configs/real/consumo/wfs/emisiones_wfs_ciudad_geojson.json
jq . asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json
jq . asset_configs/real/ingesta/ingesta_bbdd_residencial_2021_csv.json
```

Revisa evidencias:

```bash
find "evidencias/runs/$SUFFIX/phase1" -maxdepth 1 -type f
find "evidencias/runs/$SUFFIX/phase1b" -maxdepth 1 -type f
```

## Error En Contract Definition

### Síntomas

- policy creada pero contract definition no creada;
- `CD_ID` vacío;
- `phase1` o `phase1b` falla al final.

### Causas Posibles

- `ASSET_ID` incorrecto;
- `CONTRACT_POLICY_ID` incorrecto;
- permisos insuficientes;
- payload incompatible con la versión del conector;
- asset no visible en el catálogo local.

### Solución

Revisa:

```bash
echo "ASSET_ID=$ASSET_ID"
echo "CONTRACT_POLICY_ID=$CONTRACT_POLICY_ID"
echo "CD_ID=$CD_ID"
```

Revisa `summary.json`:

```bash
jq . "evidencias/runs/$SUFFIX/summary.json"
```

## Error En Negotiation, Agreement O Transfer

### Síntomas

- `phase2_consumer_negotiate.sh` no llega a `AGREED` o `FINALIZED`;
- `AGREEMENT_ID` vacío;
- `phase3_transfer_edr.sh` no obtiene EDR;
- `phase3b_inesdata_transfer.sh` no obtiene transferencia;
- `phase4_save_download.sh` no encuentra datos;
- `phase4b_consumer_storage_fetch.sh` no puede descargar desde MinIO.

### Causas Posibles

- provider y consumer cruzados;
- `contractDefinitionId` incorrecto;
- catálogo no actualizado;
- token del consumer equivocado;
- asset no disponible en provider;
- recurso HTTP externo no accesible desde dataplane;
- transferencia B2 sin credenciales S3 útiles;
- se mezclaron envs de otro `SUFFIX`.

### Solución

Comprueba el `SUFFIX` cargado:

```bash
echo "SUFFIX=$SUFFIX"
```

Comprueba que no estás mezclando runs:

```bash
source runtime/env/latest/phase1_env.sh
echo "SUFFIX=$SUFFIX"
source runtime/env/latest/phase2_env.sh
echo "SUFFIX=$SUFFIX"
```

Revisa phase2:

```bash
find "evidencias/runs/$SUFFIX/phase2" -maxdepth 1 -type f
```

Revisa phase3 o phase3b:

```bash
find "evidencias/runs/$SUFFIX/phase3" -maxdepth 1 -type f
find "evidencias/runs/$SUFFIX/phase3b" -maxdepth 1 -type f
```

## Estructura Plana Antigua

### Síntoma

Un comando o README menciona:

```text
flujos/ingesta
flujos/consumo
export_dataspace.sh en raíz
```

### Causa

Esa era una estructura anterior.

### Solución

Para IPPCP actual usa:

```text
flujos/ippcp/export_dataspace.sh
flujos/ippcp/ingesta
flujos/ippcp/consumo
```

Para histórico de pruebas usa:

```text
flujos/test3/export_dataspace.sh
flujos/test3/ingesta
flujos/test3/consumo
```

No mezcles `test3` con `ippcp`.
