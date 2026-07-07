# Runtime local IPPCP

Este directorio contiene artefactos generados localmente durante la ejecución de los flujos IPPCP.

## Env files

Los scripts generan los ficheros `phase*_env.sh` en:

```text
runtime/env/latest/
```

Los backups de envs anteriores se guardan en:

```text
runtime/env/backups/
```

Estos ficheros son runtime local y no se versionan.

## Uso

Después de ejecutar cada fase, cargar el env correspondiente desde:

```bash
source runtime/env/latest/phase0_env.sh
source runtime/env/latest/phase1_env.sh
source runtime/env/latest/phase2_env.sh
source runtime/env/latest/phase3_env.sh
```

Para B2:

```bash
source runtime/env/latest/phase1b_env.sh
source runtime/env/latest/phase3b_env.sh
```

No guardar aquí credenciales manuales ni ficheros sensibles versionables.

Las credenciales de conector viven en rutas locales ignoradas por Git:

```text
flujos/ippcp/ingesta/user_provider.sh
flujos/ippcp/ingesta/user_consumer.sh
flujos/ippcp/consumo/user_provider.sh
flujos/ippcp/consumo/user_consumer.sh
```

`runtime/env/latest/` siempre representa el último estado exportado por fase. Si ejecutas T1, T2 y T3 seguidos, no uses estos envs como única fuente para inspección histórica: fija explícitamente `SUFFIX` y `ASSET_ID` del run que quieres revisar.

Ver [`../README.md`](../README.md) y [`../scripts/scripts_README.md`](../scripts/scripts_README.md).
