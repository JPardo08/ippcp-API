# Flujo Histórico test3 De Ingesta

Este directorio conserva la configuración histórica del flujo de ingesta del dataspace `test3`.

Para operar el dataspace IPPCP actual, usar `flujos/ippcp/ingesta/`.

En este flujo, el asset de ingesta se publica desde el conector que actúa como **provider** y se consume desde el conector que actúa como **consumer**.

## Roles del flujo

| Rol | Conector |
| --- | --- |
| Provider | `conn-erick-test3` |
| Consumer | `conn-edgar-test3` |

## Ficheros versionados

```text
flujos/test3/export_dataspace.sh
flujos/test3/ingesta/export_provider.sh
flujos/test3/ingesta/export_consumer.sh
flujos/test3/ingesta/user_provider.example.sh
flujos/test3/ingesta/user_consumer.example.sh
```

Los ficheros `export_*.sh` contienen configuración no sensible del flujo: nombres de conector, hosts, URLs base y protocol endpoints.

Las plantillas `user_*.example.sh` indican qué variables de credenciales locales hay que definir.

## Ficheros locales no versionados

```text
flujos/test3/ingesta/user_provider.sh
flujos/test3/ingesta/user_consumer.sh
```

Estos ficheros contienen usuario y contraseña locales. Están ignorados por Git y no deben commitearse.

Para preparar un clone nuevo:

```bash
cp flujos/test3/ingesta/user_provider.example.sh flujos/test3/ingesta/user_provider.sh
cp flujos/test3/ingesta/user_consumer.example.sh flujos/test3/ingesta/user_consumer.sh
# Editar user_provider.sh y user_consumer.sh localmente con credenciales reales.
```

## Uso

El flujo por defecto es `ingesta`, por lo que normalmente basta con ejecutar las fases sin definir `IPPCP_FLOW`.

También puede indicarse explícitamente:

```bash
IPPCP_FLOW=ingesta IPPCP_FLOW_DIR="$PWD/flujos/test3/ingesta" $BASH_BIN scripts/phase0_context_smoke.sh
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

- suffix: `1782294549`
- asset_id: `ippcp_ingesta_bbdd_residencial_2021_csv-1782294549`
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

## Seguridad

No incluir credenciales reales en este directorio salvo en los ficheros locales ignorados:

```text
user_provider.sh
user_consumer.sh
```

No copiar contraseñas a documentación, issues, commits ni logs.
