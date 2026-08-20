# Evidence tooling architecture (internal)

T1, T2, T3 and T4 are slot positions. The asset in each slot is classified from the run.

## Slot selection

`--tests` is an exact slot set. No YAML suffixes are merged in.

- `--tests "T1=a"` => only T1
- `--tests "T1=a,T3=c"` => only T1 and T3
- `--tests "T1=a,T2=b,T3=c,T4=d"` => four-slot complete

`--only-tests` remains as a compatibility filter. It never invents slots. Golden Path SINGLE does not need it: `--tests "T1=<suffix>"` is already exact.

Historical/canonical runs are selected with an explicit preset. T* stay slots; assets are still classified from each run.

```bash
--preset legacy_assessment
```

`--profile` selects sanitization defaults only. It does not assign assets to slots.

`--sanitize-connectors` and `--redact-local-paths` remain available as overrides.

## Publication status

Each classified asset has `publication_profile` and `publication_safe`.

- `minimal_publication` => `publication_safe=true`
- `standard` (current internal delivery profile) => `publication_safe=false`

Package status is derived from the included slots, not from "contains a critical asset":

```text
package.publication_ready = all included slots are publication_safe
package.publication_blockers = ["slot T1 uses standard_internal", ...]
```

## Golden Path

Deterministic naming:

```bash
TS=$(date +%Y%m%d_%H%M%S)
EXPORT_DIR="reports/exports/$TS"
WORKBOOK="$EXPORT_DIR/ippcp_evidence_summary_${TS}.xlsx"
```

COMPLETE four slots:

```bash
python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --tests "T1=$INGESTION_SUFFIX,T2=$WFS_JUNTAS_SUFFIX,T3=$WFS_CIUDAD_SUFFIX,T4=$SPARQL_SUFFIX" \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --strict

python3 tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --tests "T1=$INGESTION_SUFFIX,T2=$WFS_JUNTAS_SUFFIX,T3=$WFS_CIUDAD_SUFFIX,T4=$SPARQL_SUFFIX" \
  --excel "$WORKBOOK" \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --strict
```

SINGLE:

```bash
python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --tests "T3=$INGESTION_SUFFIX" \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --strict
```

Historical assessment:

```bash
python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --preset legacy_assessment \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --strict
```

## Tests

```bash
conda activate data_spaces_310
cd tools/tests && PYTHONPATH=.. python -m unittest discover -v
```
