# IPPCP evidence export tools

These read-only tools transform local run evidence into reviewed delivery artifacts. They never modify source runs, runtime environments, or downloaded payloads.

## Canonical documentation

- Evidence model and commands: [`../docs/evidence-and-traceability.md`](../docs/evidence-and-traceability.md)
- Publication rules: [`../docs/evidence-publication.md`](../docs/evidence-publication.md)
- Runtime and phase behavior: [`../docs/execution-phases.md`](../docs/execution-phases.md)

This file is the concise entry point for the command-line tools. Policy and evidence semantics live in the canonical documents above.

## Requirements

Use Python 3.10 or newer and install the declared dependencies from the repository root:

```bash
python3 -m pip install -r tools/requirements-evidence-export.txt
```

## Selection behavior

- Default selection exports T1–T3 using the configured delivered baselines.
- T4 is never inferred from the local filesystem.
- A T4-only export requires explicit selection and a runtime value supplied locally.
- Mixed T1–T4 outputs are internal because T1–T3 retain delivery metadata.

Do not place runtime values in documentation, commits, filenames intended for publication, or public examples.

## Workbook export

```bash
python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --export-dir reports/exports
```

## Bundle export

Review the planned package before writing it:

```bash
python3 tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --dry-run
```

For T4, follow the strict commands and publication checks in the canonical evidence documentation. The generated workbook and ZIP remain local until their dedicated audits and manual reviews pass.

## Security boundary

Never include credential files, phase environments, sensitive JSON, raw request bodies, connector tokens, EDR access material, local paths, or downloaded business payloads in a public package. Sanitization applies to output copies only; source evidence must remain unchanged.

Run the versioned test suite after any tooling or configuration change:

```bash
python3 -m unittest \
  tools.tests.test_evidence_export \
  tools.tests.test_dataspace_resolution \
  -v
```
