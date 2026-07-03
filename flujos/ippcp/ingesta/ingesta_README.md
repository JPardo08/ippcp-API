# Flujo IPPCP De Ingesta

Este directorio contiene la configuración operativa actual del flujo de ingesta del dataspace `ippcp`.

`flujos/test3/` queda como histórico de pruebas. No mezclar `test3` con `ippcp` en una ejecución.

## Roles del flujo

| Rol | Conector |
| --- | --- |
| Provider | `conn-company-ippcp` |
| Consumer | `conn-citycouncil-ippcp` |

## Ficheros versionados

```text
flujos/ippcp/export_dataspace.sh
flujos/ippcp/ingesta/export_provider.sh
flujos/ippcp/ingesta/export_consumer.sh
flujos/ippcp/ingesta/user_provider.example.sh
flujos/ippcp/ingesta/user_consumer.example.sh
```

Los ficheros `export_*.sh` contienen configuración no sensible del flujo: nombres de conector, hosts, URLs base y protocol endpoints.

Las plantillas `user_*.example.sh` indican qué variables de credenciales locales hay que definir.

## Ficheros locales no versionados

```text
flujos/ippcp/ingesta/user_provider.sh
flujos/ippcp/ingesta/user_consumer.sh
```

Estos ficheros contienen usuario y contraseña locales. Están ignorados por Git y no deben commitearse. Los usuarios técnicos API no deben tener OTP.

Para preparar un clone nuevo:

```bash
cp flujos/ippcp/ingesta/user_provider.example.sh flujos/ippcp/ingesta/user_provider.sh
cp flujos/ippcp/ingesta/user_consumer.example.sh flujos/ippcp/ingesta/user_consumer.sh
# Editar user_provider.sh y user_consumer.sh localmente con credenciales reales.
```

## Uso

Indicar siempre el flujo anidado para evitar caer en documentación histórica:

```bash
export BASH_BIN=/usr/local/bin/bash
export IPPCP_FLOW=ingesta
export IPPCP_FLOW_DIR="$PWD/flujos/ippcp/ingesta"

$BASH_BIN scripts/phase0_context_smoke.sh
```

Después de cada fase, los envs generados se cargan desde:

```bash
source runtime/env/latest/phase0_env.sh
source runtime/env/latest/phase1_env.sh
source runtime/env/latest/phase2_env.sh
source runtime/env/latest/phase3_env.sh
```

## Cierre funcional T1

T1 final:

- suffix: `1783070399`
- asset_id: `ippcp_ingesta_bbdd_residencial_2021_csv-1783070399`
- asset_type: `InesDataStore`
- workflow: `ingesta`
- status: `PASS_WITH_NOTE`

Rol funcional:

- provider: empresa / Geoslab
- consumer: Ayuntamiento

Flujo completo:

```text
phase0 -> phase1b -> phase2 -> phase3b -> phase4b
```

La evidencia final de entrega se genera desde `tools/`, no desde este README.

`PASS_WITH_NOTE` se debe a que el transfer puede quedar en `STARTED`, pero `phase4b.storage_fetch` verifica la descarga desde MinIO consumer con `bytes` y `sha256`.

## Comandos completos

Ver `docs/ejecucion_flujos.md`, sección "Flujo 1: Asset De Ingesta / Excel-CSV".

## Seguridad

No incluir credenciales reales en este directorio salvo en los ficheros locales ignorados:

```text
user_provider.sh
user_consumer.sh
```

No copiar contraseñas a documentación, issues, commits ni logs.
