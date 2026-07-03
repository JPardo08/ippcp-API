# Flujo IPPCP De Consumo

Este directorio contiene la configuración operativa actual del flujo de consumo del dataspace `ippcp`.

En este flujo, el provider publica assets de consumo, como salidas WFS/SPARQL, y el consumer negocia y consume esos assets.

`flujos/test3/` queda como histórico de pruebas. No mezclar `test3` con `ippcp` en una ejecución.

## Roles del flujo

| Rol | Conector |
| --- | --- |
| Provider | `conn-citycouncil-ippcp` |
| Consumer | `conn-company-ippcp` |

## Ficheros versionados

```text
flujos/ippcp/export_dataspace.sh
flujos/ippcp/consumo/export_provider.sh
flujos/ippcp/consumo/export_consumer.sh
flujos/ippcp/consumo/user_provider.example.sh
flujos/ippcp/consumo/user_consumer.example.sh
```

Los ficheros `export_*.sh` contienen configuración no sensible del flujo: nombres de conector, hosts, URLs base y protocol endpoints.

Las plantillas `user_*.example.sh` indican qué variables de credenciales locales hay que definir.

## Ficheros locales no versionados

```text
flujos/ippcp/consumo/user_provider.sh
flujos/ippcp/consumo/user_consumer.sh
```

Estos ficheros contienen usuario y contraseña locales. Están ignorados por Git y no deben commitearse. Los usuarios técnicos API no deben tener OTP.

Para preparar un clone nuevo:

```bash
cp flujos/ippcp/consumo/user_provider.example.sh flujos/ippcp/consumo/user_provider.sh
cp flujos/ippcp/consumo/user_consumer.example.sh flujos/ippcp/consumo/user_consumer.sh
# Editar user_provider.sh y user_consumer.sh localmente con credenciales reales.
```

## Uso

Para usar este flujo hay que indicar explícitamente:

```bash
export BASH_BIN=/usr/local/bin/bash
export IPPCP_FLOW=consumo
export IPPCP_FLOW_DIR="$PWD/flujos/ippcp/consumo"

$BASH_BIN scripts/phase0_context_smoke.sh
```

Después de cada fase, los envs generados se cargan desde:

```bash
source runtime/env/latest/phase0_env.sh
source runtime/env/latest/phase1_env.sh
source runtime/env/latest/phase2_env.sh
source runtime/env/latest/phase3_env.sh
```

## Nota operativa

Este flujo invierte los roles respecto al flujo de ingesta:

```text
ingesta:
  provider = conn-company-ippcp
  consumer = conn-citycouncil-ippcp

consumo:
  provider = conn-citycouncil-ippcp
  consumer = conn-company-ippcp
```

## Cierre funcional T2/T3

T2 final WFS:

- suffix: `1783070513`
- asset_id: `ippcp_emisiones_wfs_ciudad_geojson-1783070513`
- asset_type: `HttpData / WFS`
- workflow: `consumo`
- status: `PASS_WITH_NOTE`

T3 final SPARQL:

- suffix: `1783070583`
- asset_id: `ippcp_emisiones_sparql_limit10_format_json-1783070583`
- asset_type: `HttpData / SPARQL`
- workflow: `consumo`
- status: `PASS_WITH_NOTE`

Rol funcional:

- provider: Ayuntamiento
- consumer: empresa / Geoslab

Flujo B1 completo:

```text
phase0 -> phase1 -> phase2 -> phase3 -> phase4
```

La evidencia final de entrega se genera desde `tools/`.

`PASS_WITH_NOTE` es aceptable porque, aunque el transfer quede en `STARTED`, `data_consumed` y `save_download` verifican la descarga con `bytes` y `sha256`.

## Comandos completos

Ver `docs/ejecucion_flujos.md`, secciones "Flujo 2: Asset HTTP WFS" y "Flujo 3: Asset HTTP SPARQL".

## Seguridad

No incluir credenciales reales en este directorio salvo en los ficheros locales ignorados:

```text
user_provider.sh
user_consumer.sh
```

No copiar contraseñas a documentación, issues, commits ni logs.
