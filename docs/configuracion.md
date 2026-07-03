# Configuración Inicial

Esta guía explica cómo preparar la configuración para operar el EdD de IPPCP por API. La configuración operativa actual está en `flujos/ippcp/`.

`flujos/test3/` existe como histórico de pruebas. No lo uses para operar el dataspace IPPCP actual.

## Estructura De Configuración

La estructura real es anidada:

```text
export_suffix.sh
endpoints.sh
flujos/ippcp/export_dataspace.sh
flujos/ippcp/ingesta/export_provider.sh
flujos/ippcp/ingesta/export_consumer.sh
flujos/ippcp/ingesta/user_provider.sh
flujos/ippcp/ingesta/user_consumer.sh
flujos/ippcp/consumo/export_provider.sh
flujos/ippcp/consumo/export_consumer.sh
flujos/ippcp/consumo/user_provider.sh
flujos/ippcp/consumo/user_consumer.sh
flujos/test3/
```

La estructura plana antigua `flujos/ingesta` y `flujos/consumo` no es la estructura operativa actual.

## Orden De Carga

Para entender una ejecución, piensa en este orden:

```bash
source ./export_suffix.sh
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/<flujo>/export_provider.sh
source ./flujos/ippcp/<flujo>/export_consumer.sh
source ./flujos/ippcp/<flujo>/user_provider.sh
source ./flujos/ippcp/<flujo>/user_consumer.sh
```

En una ejecución normal no hace falta hacer todos esos `source` manualmente. Los scripts de fase cargan el entorno desde `scripts/lib_common.sh`. Aun así, esos comandos sirven para revisar variables o diagnosticar errores.

## `export_suffix.sh`

Ruta:

```text
export_suffix.sh
```

Define:

```bash
SUFFIX="$(date +%s)"
```

`SUFFIX` es el identificador de ejecución. El repositorio no usa `run_id` ni `correlation_id` como nombre principal. Cada ejecución queda identificada por `SUFFIX`.

Cómo cargarlo manualmente:

```bash
source ./export_suffix.sh
echo "SUFFIX=$SUFFIX"
```

No contiene credenciales.

## `flujos/ippcp/export_dataspace.sh`

Ruta:

```text
flujos/ippcp/export_dataspace.sh
```

Define variables comunes del dataspace IPPCP:

```bash
DS_NAME
DS_DOMAIN
KEYCLOAK_URL
KC_CLIENT
```

Sirve para indicar a los scripts:

- qué realm de Keycloak se usa;
- qué dominio público usan los conectores;
- qué cliente OAuth se usa para pedir tokens.

Cómo cargar la configuración del dataspace:

```bash
source ./flujos/ippcp/export_dataspace.sh
```

Cómo comprobar variables no sensibles:

```bash
echo "DS_NAME=$DS_NAME"
echo "DS_DOMAIN=$DS_DOMAIN"
echo "KEYCLOAK_URL=$KEYCLOAK_URL"
echo "KC_CLIENT=$KC_CLIENT"
```

Salida esperada:

```text
DS_NAME=ippcp
DS_DOMAIN=ds.inesdata-project.eu
KEYCLOAK_URL=https://auth.ds.inesdata-project.eu
KC_CLIENT=dataspace-users
```

No imprimas tokens ni contraseñas.

## `flujos/ippcp/ingesta/export_provider.sh`

Ruta:

```text
flujos/ippcp/ingesta/export_provider.sh
```

Configura el conector provider del flujo de ingesta.

Define:

```bash
PROVIDER
PROVIDER_HOST
PROVIDER_BASE
PROVIDER_PROTOCOL
```

En el flujo de ingesta IPPCP, el provider es:

```text
conn-company-ippcp
```

Cómo cargarlo:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/ingesta/export_provider.sh
```

Cómo comprobarlo sin imprimir secretos:

```bash
echo "PROVIDER=$PROVIDER"
echo "PROVIDER_HOST=$PROVIDER_HOST"
echo "PROVIDER_BASE=$PROVIDER_BASE"
echo "PROVIDER_PROTOCOL=$PROVIDER_PROTOCOL"
```

Este fichero no contiene usuario ni contraseña.

## `flujos/ippcp/ingesta/export_consumer.sh`

Ruta:

```text
flujos/ippcp/ingesta/export_consumer.sh
```

Configura el conector consumer del flujo de ingesta.

Define:

```bash
CONSUMER
CONSUMER_HOST
CONSUMER_BASE
CONSUMER_PROTOCOL
```

En el flujo de ingesta IPPCP, el consumer es:

```text
conn-citycouncil-ippcp
```

Cómo cargarlo:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/ingesta/export_consumer.sh
```

Cómo comprobarlo sin imprimir secretos:

```bash
echo "CONSUMER=$CONSUMER"
echo "CONSUMER_HOST=$CONSUMER_HOST"
echo "CONSUMER_BASE=$CONSUMER_BASE"
echo "CONSUMER_PROTOCOL=$CONSUMER_PROTOCOL"
```

Este fichero no contiene usuario ni contraseña.

## `flujos/ippcp/consumo/export_provider.sh`

Ruta:

```text
flujos/ippcp/consumo/export_provider.sh
```

Configura el conector provider del flujo de consumo WFS/SPARQL.

Define:

```bash
PROVIDER
PROVIDER_HOST
PROVIDER_BASE
PROVIDER_PROTOCOL
```

En el flujo de consumo IPPCP, el provider es:

```text
conn-citycouncil-ippcp
```

Cómo cargarlo:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/consumo/export_provider.sh
```

Cómo comprobarlo sin imprimir secretos:

```bash
echo "PROVIDER=$PROVIDER"
echo "PROVIDER_HOST=$PROVIDER_HOST"
echo "PROVIDER_BASE=$PROVIDER_BASE"
echo "PROVIDER_PROTOCOL=$PROVIDER_PROTOCOL"
```

Este fichero no contiene usuario ni contraseña.

## `flujos/ippcp/consumo/export_consumer.sh`

Ruta:

```text
flujos/ippcp/consumo/export_consumer.sh
```

Configura el conector consumer del flujo de consumo WFS/SPARQL.

Define:

```bash
CONSUMER
CONSUMER_HOST
CONSUMER_BASE
CONSUMER_PROTOCOL
```

En el flujo de consumo IPPCP, el consumer es:

```text
conn-company-ippcp
```

Cómo cargarlo:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/consumo/export_consumer.sh
```

Cómo comprobarlo sin imprimir secretos:

```bash
echo "CONSUMER=$CONSUMER"
echo "CONSUMER_HOST=$CONSUMER_HOST"
echo "CONSUMER_BASE=$CONSUMER_BASE"
echo "CONSUMER_PROTOCOL=$CONSUMER_PROTOCOL"
```

Este fichero no contiene usuario ni contraseña.

## `user_provider.sh`

Rutas operativas:

```text
flujos/ippcp/ingesta/user_provider.sh
flujos/ippcp/consumo/user_provider.sh
```

Cada fichero local define:

```bash
PROVIDER_USERNAME
PROVIDER_PASSWORD
```

No obtiene token por sí solo. Solo carga credenciales locales. El token lo obtiene `scripts/lib_common.sh` cuando una fase llama a `lib_renew_jwt provider` o `lib_renew_jwt both`.

Antes de cargar `user_provider.sh`, carga dataspace y provider:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/ingesta/export_provider.sh
source ./flujos/ippcp/ingesta/user_provider.sh
```

Para consumo:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/consumo/export_provider.sh
source ./flujos/ippcp/consumo/user_provider.sh
```

Cómo comprobar que las variables existen sin imprimir la contraseña:

```bash
echo "PROVIDER_USERNAME=$PROVIDER_USERNAME"
echo "PROVIDER_PASSWORD_LEN=${#PROVIDER_PASSWORD}"
```

Cómo validar el usuario provider contra Keycloak:

```bash
curl -sS -w '\nHTTP=%{http_code}\n' -X POST "$KEYCLOAK_URL/realms/$DS_NAME/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "client_id=$KC_CLIENT" \
  --data-urlencode "username=$PROVIDER_USERNAME" \
  --data-urlencode "password=$PROVIDER_PASSWORD" \
  --data-urlencode "scope=openid profile email"
```

Salida esperada:

```text
HTTP=200
```

El body debe contener `access_token`. No copies ese token a documentación ni chats.

Errores típicos:

- `invalid_grant`: credenciales incorrectas, usuario inexistente en el realm, email no verificado o acción pendiente;
- OTP/MFA activo: el flujo automatizado no puede completar la interacción de OTP;
- `invalid_client`: `KC_CLIENT` incorrecto o no disponible en el realm;
- `401`: autenticación rechazada;
- `403`: autenticado pero sin permisos suficientes;
- URL de token vacía o mal formada: no se cargó `flujos/ippcp/export_dataspace.sh`.

## `user_consumer.sh`

Rutas operativas:

```text
flujos/ippcp/ingesta/user_consumer.sh
flujos/ippcp/consumo/user_consumer.sh
```

Cada fichero local define:

```bash
CONSUMER_USERNAME
CONSUMER_PASSWORD
```

No obtiene token por sí solo. Solo carga credenciales locales. El token lo obtiene `scripts/lib_common.sh` cuando una fase llama a `lib_renew_jwt consumer` o `lib_renew_jwt both`.

Antes de cargar `user_consumer.sh`, carga dataspace y consumer:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/ingesta/export_consumer.sh
source ./flujos/ippcp/ingesta/user_consumer.sh
```

Para consumo:

```bash
source ./flujos/ippcp/export_dataspace.sh
source ./flujos/ippcp/consumo/export_consumer.sh
source ./flujos/ippcp/consumo/user_consumer.sh
```

Cómo comprobar que las variables existen sin imprimir la contraseña:

```bash
echo "CONSUMER_USERNAME=$CONSUMER_USERNAME"
echo "CONSUMER_PASSWORD_LEN=${#CONSUMER_PASSWORD}"
```

Cómo validar el usuario consumer contra Keycloak:

```bash
curl -sS -w '\nHTTP=%{http_code}\n' -X POST "$KEYCLOAK_URL/realms/$DS_NAME/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "client_id=$KC_CLIENT" \
  --data-urlencode "username=$CONSUMER_USERNAME" \
  --data-urlencode "password=$CONSUMER_PASSWORD" \
  --data-urlencode "scope=openid profile email"
```

Salida esperada:

```text
HTTP=200
```

El body debe contener `access_token`. No copies ese token a documentación ni chats.

Errores típicos:

- `invalid_grant`: credenciales incorrectas, usuario inexistente en el realm, email no verificado o acción pendiente;
- OTP/MFA activo: el flujo automatizado no puede completar la interacción de OTP;
- `invalid_client`: `KC_CLIENT` incorrecto o no disponible en el realm;
- `401`: autenticación rechazada;
- `403`: autenticado pero sin permisos suficientes;
- URL de token vacía o mal formada: no se cargó `flujos/ippcp/export_dataspace.sh`.

## `endpoints.sh`

Ruta:

```text
endpoints.sh
```

Define el array asociativo `ENDPOINTS` con rutas relativas de Management API:

```text
asset
policyDefinition
contractDefinition
contractAgreement
transferProcess
vocabulary
```

No contiene secretos. Lo cargan los scripts automáticamente.

## Selección Automática De Dataspace

Los scripts usan `IPPCP_FLOW_DIR` para inferir el dataspace:

```bash
export IPPCP_FLOW_DIR="$PWD/flujos/ippcp/ingesta"
```

Con esa ruta, `scripts/lib_common.sh` busca:

```text
flujos/ippcp/export_dataspace.sh
```

Si necesitas forzar el dataspace:

```bash
export IPPCP_DATASPACE_DIR="$PWD/flujos/ippcp"
```

Si necesitas forzar el fichero exacto:

```bash
export IPPCP_DATASPACE_FILE="$PWD/flujos/ippcp/export_dataspace.sh"
```

En operación normal IPPCP basta con definir `IPPCP_FLOW_DIR`.
