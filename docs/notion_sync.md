# Sincronización Con Notion

Este documento registra cómo mantener alineada la documentación del repositorio con Notion.

La referencia técnica para terceros debe ser el repositorio compartible:

```text
https://github.com/JPardo08/ippcp-API.git
```

El repositorio interno de trabajo puede mencionarse solo como contexto interno. No debe presentarse como repositorio operativo para terceros.

## Página Principal Relacionada

Página indicada para documentación de APIs:

```text
https://app.notion.com/p/APIs-380f98df2fe3807e84d3ed5dd33be306
```

## Actualización Realizada

Se añadieron secciones nuevas al final de estas páginas, sin borrar histórico:

```text
APIs
https://app.notion.com/p/380f98df2fe3807e84d3ed5dd33be306

Automatización APIs - Plan de ejecución
https://app.notion.com/p/384f98df2fe3818d9454e02916d786b0
```

Contenido añadido:

- estado posterior al despliegue del EdD IPPCP;
- repositorio compartible `https://github.com/JPardo08/ippcp-API.git`;
- separación entre `flujos/ippcp/` operativo y `flujos/test3/` histórico;
- usuarios técnicos API sin OTP;
- estructura de configuración actual;
- tres flujos validados;
- suffixes T1/T2/T3;
- evidencias, `summary.json`, descargas y manifests;
- troubleshooting principal.

Las actualizaciones en Notion deben ser append-only:

- no borrar histórico;
- no sustituir páginas enteras;
- añadir secciones nuevas al final;
- corregir solo errores puntuales claros;
- no copiar tokens, passwords ni salidas sensibles.

## Sección A Añadir En Notion

Título recomendado:

```text
Actualización posterior al despliegue del EdD IPPCP
```

Contenido que debe quedar reflejado:

- EdD IPPCP levantado;
- problemas iniciales corregidos;
- automatización API validada sobre el dataspace `ippcp`;
- tres assets probados: ingesta / Excel-CSV, HTTP WFS, HTTP SPARQL;
- repositorio compartible: `https://github.com/JPardo08/ippcp-API.git`;
- repositorio interno de trabajo mantenido privado;
- usuarios técnicos API sin OTP;
- estructura real `flujos/ippcp/export_dataspace.sh`, `flujos/ippcp/ingesta/`, `flujos/ippcp/consumo/`;
- `flujos/test3/` como histórico de pruebas;
- evidencias bajo `evidencias/runs/<SUFFIX>/`;
- `summary.json` como resumen técnico por ejecución.

## Suffixes IPPCP Validados

```text
T1 ingesta / Excel-CSV: 1783070399
T2 HTTP WFS:            1783070513
T3 HTTP SPARQL:         1783070583
```

## Contenido Que No Debe Copiarse A Notion

No copiar:

- passwords;
- access tokens;
- refresh tokens;
- client secrets;
- claves `.pem` o `.key`;
- `.env`;
- salidas completas de comandos que contengan tokens;
- ficheros `*.sensitive.json`;
- `phase*_env.sh`;
- `user_provider.sh`;
- `user_consumer.sh`.

Usar placeholders seguros:

```text
<KEYCLOAK_URL>
<REALM>
<CLIENT_ID>
<PROVIDER_API_URL>
<CONSUMER_API_URL>
<DATASPACE_URL>
<USERNAME>
<PASSWORD>
```

## Checklist De Actualización

Antes de actualizar Notion:

```bash
git status -sb
```

Comprueba que los documentos locales están actualizados:

```text
README.md
docs/configuracion.md
docs/ejecucion_flujos.md
docs/evidencias.md
docs/troubleshooting.md
```

Después de actualizar Notion, registra en el resumen final:

- páginas actualizadas;
- secciones añadidas;
- contenido pendiente;
- si hubo páginas históricas que se dejaron intactas.
