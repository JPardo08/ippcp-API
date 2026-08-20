# IPPCP evidence delivery tools

Read-only tools that turn local run evidence into reviewed delivery artifacts:

```text
original evidencias/runs -> Excel summary -> sanitized ZIP -> secret/publication audit
```

They never modify `evidencias/runs/`, `downloads/`, phase environments, or the Bash phase scripts.

Architecture notes for these exporters: [`evidence_tooling.md`](evidence_tooling.md).

Security exclusions and the publication review boundary: [`../docs/evidence-publication.md`](../docs/evidence-publication.md).

## Requirements

Python 3.10 or newer. From the repository root:

```bash
python3 -m pip install -r tools/requirements-evidence-export.txt
```

Declared dependencies: `openpyxl`, `PyYAML`.

## Slots are not asset types

`T1`, `T2`, `T3`, and `T4` are slot positions. The asset in a slot is classified from the run (`summary.json`, `asset_slug`, `asset_config`, phases, `transfer_type`, `media_type`). Slot ids never select:

- asset family or variant;
- criticality;
- publication profile;
- sanitization;
- renderer.

`tools/evidence_export.tests.yaml` holds the asset registry, connector aliases, workflow-role expectations, and named presets. It does not assign an asset type to a slot.

## Slot selection

`--tests` is an exact slot set. No other slots are added from YAML defaults.

| Command | Selected slots |
| --- | --- |
| `--tests "T1=<suffix>"` | T1 only |
| `--tests "T1=<suffix>,T3=<suffix>"` | T1 and T3 only |
| `--tests "T1=<s1>,T2=<s2>,T3=<s3>,T4=<s4>"` | four-slot complete |

Without `--tests` or `--preset`, the CLI fails. There is no implicit T1–T3 (or T4) selection.

`--preset NAME` selects a named historical or canonical slot map from the config. It does not bind asset types to slots. Current presets:

- `legacy_assessment`: delivered T1–T3 assessment runs;
- `legacy_test3`: test3-era historical suffixes.

`--only-tests` filters an already selected set (`--tests` or `--preset`). It never invents slots. Golden Path SINGLE does not need it: `--tests "T3=<suffix>"` is already exact.

If both `--tests` and `--preset` are passed, `--tests` wins and `--preset` is ignored.

`--profile` selects sanitization defaults only. It does not assign assets to slots.

`--sanitize-connectors` and `--redact-local-paths` remain available as overrides.

Do not place runtime suffixes in commits, public examples, or filenames intended for publication. Pass them as local variables.

## Publication status

Each classified asset has `publication_profile` and `publication_safe`.

- `minimal_publication` → `publication_safe=true` (metadata-only projection, allowlisted JSON).
- `standard` (current delivery profile) → `publication_safe=false` (`standard_internal`).

Package status is derived from the included slots, not from “the package contains a critical asset”:

```text
package.publication_ready = all included slots are publication_safe
package.publication_blockers = slot T1 uses standard_internal
```

A four-slot workbook or ZIP can be `publication_ready=true` only when every selected representation is publication-safe under its policy. Mixed complete packages with `standard` slots remain internal, with blockers named per slot. A current complete that includes WFS/SPARQL is normally `publication_ready=false`. Do not send that package externally.

Automated sanitization is a safeguard. Manual review remains mandatory before any public release.

## Deterministic output names

Do not pass globs such as `ippcp_evidence_summary_*.xlsx` to `--excel`.

```bash
TS=$(date +%Y%m%d_%H%M%S)
EXPORT_DIR="reports/exports/$TS"
WORKBOOK="$EXPORT_DIR/ippcp_evidence_summary_${TS}.xlsx"
```

Expected files:

```text
reports/exports/<TIMESTAMP>/
  ippcp_evidence_summary_<TIMESTAMP>.xlsx
  ippcp_evidence_package_<TIMESTAMP>.zip
```

## Golden Path

Set local run ids, then export. The slot is a position; the asset is whatever the run classifies as.

```bash
export INGESTION_SUFFIX=<suffix>
export WFS_JUNTAS_SUFFIX=<suffix>
export WFS_CIUDAD_SUFFIX=<suffix>
export SPARQL_SUFFIX=<suffix>

TS=$(date +%Y%m%d_%H%M%S)
EXPORT_DIR="reports/exports/$TS"
WORKBOOK="$EXPORT_DIR/ippcp_evidence_summary_${TS}.xlsx"
```

### Complete, four slots

```bash
TESTS="T1=$INGESTION_SUFFIX,T2=$WFS_JUNTAS_SUFFIX,T3=$WFS_CIUDAD_SUFFIX,T4=$SPARQL_SUFFIX"

python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --tests "$TESTS" \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --strict

python3 tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --tests "$TESTS" \
  --excel "$WORKBOOK" \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --strict
```

### Complete, two slots in arbitrary order

```bash
TESTS="T3=$SPARQL_SUFFIX,T1=$WFS_CIUDAD_SUFFIX"

python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --tests "$TESTS" \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --strict
```

Only T1 and T3 are selected. T2 and T4 are not filled in.

### Single: Ingestion API in T3

```bash
python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --tests "T3=$INGESTION_SUFFIX" \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --strict
```

Expected classification: `ingestion_api_v2`, `critical=true`, `publication_profile=minimal_publication`, `publication_safe=true`.

### Single: WFS ciudad in T1

```bash
python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --tests "T1=$WFS_CIUDAD_SUFFIX" \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --strict
```

Expected classification: `wfs_ciudad`, `publication_profile=standard`, `publication_safe=false`, blocker `slot T1 uses standard_internal`.

### Historical assessment preset

```bash
python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --preset legacy_assessment \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --strict

python3 tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --preset legacy_assessment \
  --excel "$WORKBOOK" \
  --timestamp "$TS" \
  --export-dir "$EXPORT_DIR" \
  --strict
```

Subset of a preset: `--preset legacy_assessment --only-tests T1`.

Review a package without writing a ZIP:

```bash
python3 tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --tests "$TESTS" \
  --excel "$WORKBOOK" \
  --dry-run \
  --verbose
```

## Workbook contents

The Excel workbook includes:

- `Slot Map`
- `Summary`
- one sheet per selected slot (name derived from slot plus classified asset slug)
- `Raw JSON Index`
- `Evidence Checklist`
- `Package Manifest`

Missing JSON fields are written as `not_found`.

A `minimal_publication` slot uses the allowlisted metadata projection. Runtime suffixes of those slots must not appear in the output filename.

## Package contents

Every package includes `package_status.json` (`publication_ready`, `publication_blockers`, per-slot inventory fields) and `slot_inventory.json`.

`standard` slots may include sanitized copies of selected run artifacts. Those copies may retain real identifiers, local paths, global snapshots, and cross-asset references. `minimal_publication` slots include only allowlisted JSON (`sanitized_summary.json`, `sanitized_manifest.json`, `validation_status.json`) under the slot folder. Downloaded payloads are forbidden for those slots. Excel is not added to a package that contains only `minimal_publication` slots. The warning `Excel inclusion is disabled for minimal_publication-only packages` is expected and is not a failure.

## Security boundary

Never include in a public package:

- credential files;
- phase environments;
- `*.sensitive.json` / `*.secret.json`;
- raw request bodies;
- connector tokens;
- EDR access material;
- local filesystem paths;
- downloaded business payloads;
- Ingestion API keys or provider identifiers.

Sanitization applies to output copies only. Source evidence must remain unchanged.

Connector aliases in output copies:

- `conn-erick-test3` → `conn-company-ippcp`
- `conn-edgar-test3` → `conn-citycouncil-ippcp`

`--redact-local-paths` replaces absolute repository paths with `<repo-root>`.

## Tests

After any tooling or exporter-config change:

```bash
cd tools/tests && PYTHONPATH=.. python3 -m unittest discover -v
```
