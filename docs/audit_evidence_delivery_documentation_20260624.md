# Auditoría documental — Entrega de evidencias IPPCP

## 1. Contexto de la auditoría

Esta auditoría documental se realiza tras completar la ejecución funcional de las tres pruebas IPPCP y generar la cadena de entrega de evidencias:

```text
evidencias originales -> Excel resumen -> ZIP sanitizado -> auditoría anti-secretos
```

El objetivo de este documento es identificar qué documentación del repositorio debería actualizarse antes del cierre/commit, qué información debe incorporarse y qué cambios conviene posponer. Esta fase no modifica la documentación principal ni las evidencias originales.

Restricciones aplicables:

- Las herramientas de entrega son read-only sobre `evidencias/runs/` y `downloads/`.
- La sanitización se aplica solo sobre copias de salida.
- Los scripts Bash de fase no deben modificarse como parte de la documentación de entrega.
- Los artefactos bajo `reports/exports/<TIMESTAMP>/` son regenerables.
- Los Excel/ZIP finales son artefactos de entrega, no la fuente de verdad.

## 2. Estado funcional validado

Pruebas finales validadas:

| Test | Suffix | Workflow | Asset type | Asset ID | Estado |
| ---- | ------ | -------- | ---------- | -------- | ------ |
| T1 | `1782294549` | `ingesta` | `InesDataStore` | `ippcp_ingesta_bbdd_residencial_2021_csv-1782294549` | `PASS_WITH_NOTE` |
| T2 | `1782299532` | `consumo` | `HttpData / WFS` | `ippcp_emisiones_wfs_ciudad_geojson-1782299532` | `PASS_WITH_NOTE` |
| T3 | `1782299641` | `consumo` | `HttpData / SPARQL` | `ippcp_emisiones_sparql_limit10_format_json-1782299641` | `PASS_WITH_NOTE` |

Entrega final validada en esta iteración:

```text
reports/exports/20260624_131749/
  ippcp_evidence_summary_20260624_131749.xlsx
  ippcp_evidence_package_20260624_131749.zip
```

Validaciones realizadas:

- Excel generado correctamente.
- ZIP generado correctamente.
- `unzip -t` OK.
- Auditoría real descomprimiendo a temporal OK.
- No aparecen conectores reales `conn-erick-test3` ni `conn-edgar-test3` en el paquete sanitizado.
- No aparecen patrones sensibles `secretAccessKey`, `accessKeyId` ni JWT-like `eyJ...`.
- El paquete final incluye 270 entradas y excluye 16.
- `phase3b/21_transfer_final_state.sensitive.json` queda excluido y registrado como sensible.
- `package_manifest.json/csv` tienen tratamiento autorreferencial corregido: sus propias filas no declaran `sha256` ni `size_bytes`, y usan `exclusion_reason=self-referential`.

Interpretación de `PASS_WITH_NOTE`:

- En B2, el transfer puede quedar en `STARTED`, pero la descarga desde MinIO consumer queda verificada por `phase4b.storage_fetch`, bytes y hash.
- En B1, el transfer puede quedar en `STARTED`, pero la descarga queda verificada por `data_consumed`, `save_download`, bytes y hash.

## 3. Cambios técnicos introducidos

Herramientas nuevas implementadas:

```text
tools/evidence_common.py
tools/export_evidence_to_excel.py
tools/package_evidence_bundle.py
tools/evidence_export.tests.yaml
tools/requirements-evidence-export.txt
tools/tools_README.md
```

Resumen técnico:

- `tools/export_evidence_to_excel.py`: genera un Excel legible con `Summary`, hojas por test, índice raw, checklist KPI y package manifest recomendado.
- `tools/package_evidence_bundle.py`: genera un ZIP sanitizado con evidencias no sensibles, Excel opcional, `README_PACKAGE.txt`, `package_manifest.json` y `package_manifest.csv`.
- `tools/evidence_common.py`: centraliza carga de configuración, parsers read-only, indexación de ficheros, sanitización, validación semántica de conectores, escaneo de secretos y hashes.
- `tools/evidence_export.tests.yaml`: configura T1/T2/T3, suffixes, flujos, conectores reales, alias públicos y roles esperados.
- Sanitización de conectores: sustituye conectores reales por aliases públicos solo en copias de salida.
- Redacción de rutas locales: sustituye rutas absolutas del repo por `<repo-root>` en artefactos exportados.
- Auditoría anti-secretos: excluye patrones sensibles, detecta claves peligrosas y valida que el ZIP sanitizado no contenga conectores reales ni tokens.
- Salida timestamped: permite generar entregas aisladas bajo `reports/exports/<TIMESTAMP>/`.

## 4. Documentación revisada

- `README.md`: documenta alcance, estructura del repo, flujos A/B1/B2, evidencias JSON, runtime, downloads y seguridad. Todavía no incorpora la cadena Excel/ZIP ni la carpeta `reports/exports/<TIMESTAMP>/`.
- `scripts/scripts_README.md`: documenta scripts de fase, seguridad de evidencias y flujos B1/B2. No incluye aún el paso posterior de exportación Excel/ZIP ni la interpretación formal de `PASS_WITH_NOTE`.
- `runtime/runtime_README.md`: explica envs locales generados y credenciales fuera de Git. Está alineado con la política de no versionar envs; podría reforzar que estos ficheros tampoco entran en paquetes de entrega.
- `downloads/downloads_README.md`: explica `downloads/assets/` y `downloads/manifests/`. No documenta la relación entre manifests canónicos y paquetes en `reports/exports/`.
- `data/real/real_README.md`: documenta datos reales, WFS/SPARQL e ingesta. Mantiene notas de estado operativo/pending que conviene revisar tras las pruebas finales.
- `flujos/ingesta/ingesta_README.md`: roles de ingesta correctos (`provider=conn-erick-test3`, `consumer=conn-edgar-test3`). No menciona T1 final ni la entrega de evidencias.
- `flujos/consumo/consumo_README.md`: roles de consumo correctos (`provider=conn-edgar-test3`, `consumer=conn-erick-test3`). No menciona T2/T3 finales ni la entrega de evidencias.
- `tools/tools_README.md`: ya documenta las herramientas de entrega, sanitización, `--export-dir`, `--timestamp` y seguridad. Debe revisarse para sustituir referencias a T2/T3 como placeholders por los suffixes finales.
- `docs/repo_inventory.md`: documento histórico de inventario/reorganización. Contiene rutas/estado previos y no debe tratarse como documentación funcional actual.
- `docs/repo_cleanup_plan.md`: plan histórico de limpieza/reorganización. Útil como contexto, pero no refleja la entrega final Excel/ZIP.

## 5. Brechas documentales detectadas

- `tools/tools_README.md` todavía indica que T2/T3 son placeholders editables; tras la validación final deben reflejarse los suffixes `1782299532` y `1782299641`.
- `README.md` no menciona las herramientas de entrega (`tools/export_evidence_to_excel.py`, `tools/package_evidence_bundle.py`) ni el flujo `evidencias originales -> Excel -> ZIP -> auditoría`.
- `README.md` y `scripts/scripts_README.md` hablan de evidencias JSON y manifests, pero no explican el paquete final Excel/ZIP ni la carpeta timestamped `reports/exports/<TIMESTAMP>/`.
- Algunos ejemplos de comandos documentados siguen centrados en ejecución de fases y no en entrega final con `--timestamp` / `--export-dir`.
- Falta una política documental explícita sobre si `reports/exports/` debe ignorarse, versionarse parcialmente o tratarse siempre como artefacto regenerable fuera de Git.
- No hay una explicación centralizada de que `PASS_WITH_NOTE` es aceptable cuando existe descarga verificada con bytes/hash.
- `downloads/downloads_README.md` no aclara todavía que `downloads/manifests/<ASSET_ID>/latest.manifest.json` es fuente para el paquete final, pero que el ZIP/Excel son copias sanitizadas.
- `flujos/ingesta/ingesta_README.md` y `flujos/consumo/consumo_README.md` no enlazan el resultado final de cada flujo con las evidencias de entrega.
- `docs/repo_inventory.md` y `docs/repo_cleanup_plan.md` pueden inducir confusión si se leen como estado actual, porque son documentos históricos de reorganización.

## 6. Recomendaciones de actualización

### `tools/tools_README.md`

- Estado actual observado: documenta correctamente las herramientas, el flujo timestamped y la política de seguridad, pero aún indica que T2/T3 son placeholders editables.
- Cambio recomendado: actualizar la sección de configuración para reflejar T1/T2/T3 finales (`1782294549`, `1782299532`, `1782299641`) y añadir una nota de que futuros reruns deben cambiarse explícitamente en `tools/evidence_export.tests.yaml`.
- Prioridad: Alta.
- Riesgo si no se cambia: el usuario puede generar una entrega con suffixes antiguos o creer que T2/T3 no están cerrados.

### `README.md`

- Estado actual observado: describe flujos, estructura, runtime, downloads y evidencias JSON, pero no menciona la capa de entrega Excel/ZIP ni `reports/exports/<TIMESTAMP>/`.
- Cambio recomendado: añadir una sección breve de "Entrega de evidencias" que enlace a `tools/tools_README.md`, explique la cadena Excel/ZIP/auditoría y aclare que `reports/exports/` contiene artefactos regenerables.
- Prioridad: Alta.
- Riesgo si no se cambia: la documentación principal queda incompleta respecto al entregable final y puede parecer que solo existen JSONs sueltos.

### `scripts/scripts_README.md`

- Estado actual observado: documenta fases, artefactos JSON/HTTP y seguridad; no documenta el paso posterior de exportación ni el criterio `PASS_WITH_NOTE`.
- Cambio recomendado: añadir al final de "Evidencias" o de los flujos reales una referencia a ejecutar las herramientas de `tools/` tras completar las fases, y explicar que `STARTED` puede ser aceptable si hay descarga verificada con bytes/hash.
- Prioridad: Media/Alta.
- Riesgo si no se cambia: se puede interpretar erróneamente que un transfer `STARTED` invalida una prueba materialmente descargada.

### `downloads/downloads_README.md`

- Estado actual observado: explica assets y manifests locales, y que no se versionan. No conecta esos manifests con el ZIP final.
- Cambio recomendado: añadir una nota breve sobre que los manifests canónicos de `downloads/manifests/<ASSET_ID>/latest.manifest.json` son usados por las herramientas de entrega, pero que `downloads/` sigue siendo generado/no versionado.
- Prioridad: Media.
- Riesgo si no se cambia: puede no quedar clara la trazabilidad entre descarga local, manifest y paquete sanitizado.

### `flujos/ingesta/ingesta_README.md`

- Estado actual observado: roles correctos y seguridad de credenciales, sin referencia al resultado final T1.
- Cambio recomendado: añadir una nota de cierre indicando que el flujo T1 final validado corresponde a suffix `1782294549`, asset `ippcp_ingesta_bbdd_residencial_2021_csv-1782294549`, y que la evidencia de entrega se genera desde `tools/`.
- Prioridad: Media.
- Riesgo si no se cambia: el flujo de ingesta queda documentado operativamente, pero no conectado con el entregable final.

### `flujos/consumo/consumo_README.md`

- Estado actual observado: roles correctos e inversión respecto a ingesta, sin referencia a T2/T3 finales.
- Cambio recomendado: añadir nota de cierre para T2 WFS (`1782299532`) y T3 SPARQL (`1782299641`), indicando que son flujos B1/HttpData y que la entrega final se genera desde `tools/`.
- Prioridad: Media.
- Riesgo si no se cambia: se pierde trazabilidad entre los runs finales de consumo y la documentación del flujo.

### `runtime/runtime_README.md`

- Estado actual observado: documenta envs locales y credenciales fuera de Git. Correcto y conciso.
- Cambio recomendado: opcionalmente añadir una frase indicando que `phase*_env.sh` tampoco debe entrar en paquetes ZIP de entrega.
- Prioridad: Baja.
- Riesgo si no se cambia: bajo; la política ya está implícita, aunque no conectada con el empaquetador.

### `data/real/real_README.md`

- Estado actual observado: documenta WFS/SPARQL e ingesta, incluyendo notas pending. No refleja explícitamente que WFS ciudad y SPARQL format JSON ya fueron validados como T2/T3.
- Cambio recomendado: revisar si procede actualizar el estado de WFS ciudad y SPARQL format JSON como validados, manteniendo pending solo para endpoints realmente pendientes.
- Prioridad: Baja/Media.
- Riesgo si no se cambia: puede quedar una lectura ambigua sobre qué datasets reales ya fueron usados con éxito.

### `docs/`

- Estado actual observado: contiene `repo_inventory.md` y `repo_cleanup_plan.md`, ambos útiles como histórico de reorganización pero no como documentación funcional final.
- Cambio recomendado: conservar esta auditoría como documento puente antes de editar documentación principal; opcionalmente añadir en el futuro un documento de cierre de entrega o release note.
- Prioridad: Opcional.
- Riesgo si no se cambia: bajo; el riesgo principal es confundir documentos históricos con estado funcional actual.

## 7. Cambios que NO deben hacerse todavía

- No reescribir scripts Bash.
- No modificar evidencias originales.
- No versionar secretos ni `.sensitive.json`.
- No convertir Excel/ZIP en fuente de verdad.
- No borrar runs antiguos todavía salvo decisión explícita.
- No cambiar nombres reales de conectores en evidencias originales.
- No asumir que `reports/exports/` debe versionarse; decidirlo explícitamente.
- No modificar `downloads/` ni `evidencias/runs/` para que coincidan con aliases públicos.
- No cambiar IDs técnicos (`agreement_id`, `transfer_id`, `offer_policy_id`, `asset_id`, `sha256`) en la documentación de trazabilidad.

## 8. Propuesta de orden de edición

Orden conservador recomendado para una fase posterior:

1. `tools/tools_README.md`
2. `README.md`
3. `scripts/scripts_README.md`
4. `downloads/downloads_README.md`
5. `flujos/ingesta/ingesta_README.md`
6. `flujos/consumo/consumo_README.md`
7. documentación opcional en `docs/`

Razonamiento:

- Primero actualizar la documentación más cercana a las herramientas nuevas.
- Después resumir en el README raíz sin duplicar detalle.
- Luego conectar las fases Bash y los downloads con la entrega final.
- Finalmente añadir trazabilidad por flujo.

## 9. Riesgos de documentación

- Suffixes desalineados: si `tools/evidence_export.tests.yaml` conserva suffixes antiguos o placeholders, la entrega puede generarse con runs no finales.
- Ambigüedad de `PASS_WITH_NOTE`: si no se documenta, revisores pueden interpretar `STARTED` como fallo aunque haya descarga verificada.
- Confusión entre fuente de verdad y paquete: los JSON originales y manifests son la fuente; Excel/ZIP son una capa de entrega sanitizada.
- Exposición accidental de información sensible: copiar ejemplos reales sin sanitización puede reintroducir conectores reales o rutas locales donde no conviene.
- Versionado de artefactos pesados: `reports/exports/` puede contener ZIP/Excel y assets descargados; debe decidirse explícitamente si se ignora o se entrega fuera de Git.
- Documentos históricos: `docs/repo_inventory.md` y `docs/repo_cleanup_plan.md` pueden quedar obsoletos respecto al estado actual si no se contextualizan.
- Duplicación de comandos: si README raíz y `tools/tools_README.md` divergen, los usuarios podrían ejecutar flujos distintos.

## 10. Checklist previo al commit

Comandos mínimos:

```bash
git status -sb
grep -nE 'T1:|T2:|T3:|suffix:' tools/evidence_export.tests.yaml
python -m py_compile tools/evidence_common.py tools/export_evidence_to_excel.py tools/package_evidence_bundle.py
unzip -t reports/exports/20260624_131749/ippcp_evidence_package_20260624_131749.zip
```

Checklist textual:

- Confirmar que `tools/evidence_export.tests.yaml` tiene los suffixes finales:
  - T1: `1782294549`
  - T2: `1782299532`
  - T3: `1782299641`
- Confirmar que T1/T2/T3 aparecen como `PASS_WITH_NOTE` en el Excel final.
- Confirmar auditoría anti-secretos:
  - sin `conn-erick-test3`
  - sin `conn-edgar-test3`
  - sin `secretAccessKey`
  - sin `accessKeyId`
  - sin JWT-like `eyJ...`
- Confirmar que `phase3b/21_transfer_final_state.sensitive.json` está excluido y registrado como sensible.
- Confirmar que `package_manifest.json/csv` tratan sus propias filas como `self-referential`, sin `sha256` ni `size_bytes`.
- Confirmar que no se versionan artefactos pesados si no procede.
- Revisar `.gitignore` para decidir si `reports/exports/` debe excluirse.
- Confirmar que el documento de auditoría es el único cambio documental de esta fase.
- Confirmar que no se modificaron `README.md`, `scripts/scripts_README.md`, `tools/tools_README.md` ni otros documentos principales durante esta fase.
