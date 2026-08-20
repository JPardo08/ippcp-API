# Evidence Publication Policy

## Purpose

This policy defines the boundary between internal IPPCP execution evidence and artifacts that may be shown in a demonstration or considered for public release.

The policy applies to evidence derived from the current phase scripts and evidence export tools. It does not make an artifact public automatically. Automated sanitization is a safeguard; manual review and explicit publication approval remain mandatory.

The canonical execution and traceability model is documented in [Evidence and traceability](evidence-and-traceability.md). Exporter commands: [`tools/tools_README.md`](../tools/tools_README.md). Tooling model: [`tools/evidence_tooling.md`](../tools/evidence_tooling.md).

## Evidence tiers

### Internal raw evidence

Internal raw evidence is the original execution record produced under the run directory, runtime state, download directory, and related local logs.

It may contain:

- concrete execution and connector identifiers;
- Management API requests and responses;
- provider data-address details;
- EDR endpoint information;
- local filesystem paths;
- phase environment files;
- downloaded business payloads;
- diagnostic material that is unsafe to publish.

Internal raw evidence is never a public artifact. It must remain in access-controlled project storage.

### Sanitized internal evidence

Sanitized internal evidence is a transformed copy prepared for internal review, assessment, or troubleshooting. It may retain more technical detail than a public example, but it must remove credentials and authorization values.

Sanitized internal evidence is still internal unless it passes the public review defined below. The word “sanitized” does not imply approval for publication.

### Demo-visible evidence

Demo-visible evidence is the smallest reviewed subset needed to explain an observable result during a presentation.

It may show:

- phase and step statuses;
- flow type;
- placeholder identifiers;
- a sanitized summary structure;
- a sanitized manifest structure;
- byte count;
- the SHA-256 concept or an approved value;
- semantic validation status;
- a reviewed package inventory.

Demo-visible evidence must not expose raw operational files or downloaded business data. Prepared screenshots, recordings, and offline evidence packages require the same review as files intended for publication.

### Public example evidence

Public example evidence is a tracked, structurally representative example built from synthetic values or from a verified sanitizer applied to synthetic fixtures.

Public examples:

- are not raw output from an internal run;
- do not prove that a specific private execution occurred;
- use placeholders or explicitly synthetic values;
- contain no source payload;
- contain no private endpoint, path, credential, or identifier;
- are reviewed as public documentation.

## Publication profiles

An evidence profile defines the artifacts and fields that an exporter may release. Profiles are properties of a **classified asset**, not of a slot id.

`minimal_publication` belongs to `ingestion_api_v2`. It is metadata-only. It uses an explicit archive-entry allowlist and field-level JSON allowlists. It does not copy a complete run directory and then attempt to remove unsafe files. The same profile applies when that asset occupies T1, T2, T3, or T4.

`standard` is the current delivery profile for CSV/B2 legacy, WFS, and SPARQL. It is `publication_safe=false` (`standard_internal`). Those slots may retain real identifiers, local paths, global snapshots, and cross-asset references. A package is `publication_ready` only when every included slot is `publication_safe`. A current four-slot complete that includes WFS/SPARQL is therefore internal. Do not send a `publication_ready=false` package externally.

Unlike an unauthenticated public endpoint, the Ingestion API requires provider-side `X-Api-Key` and `X-Provider-Id` values at the Provider Data Plane boundary. They remain invisible to the consumer and are not carried in the EDR. The evidence tools neither obtain nor propagate these operational values, and no package, workbook, or public example may contain them.

CSV/B2/InesDataStore remains a legacy historical baseline. It is not the current Golden Path.

### `minimal_publication` archive-entry allowlist

A package that contains only `minimal_publication` slots contains exactly:

```text
ippcp_evidence_package/
  README_PACKAGE.txt
  package_manifest.json
  package_manifest.csv
  package_status.json
  slot_inventory.json
  <slot>_<asset-slug>/
    sanitized_summary.json
    sanitized_manifest.json
    validation_status.json
```

The folder name is derived from the slot plus the classified asset slug (for example `T3_ingestion_api` when Ingestion API occupies T3). It is not hard-wired to `T4_ingestion_api`.

Any unknown archive entry fails strict validation. Excel is not included. The exporter may print:

```text
WARN: Excel inclusion is disabled for minimal_publication-only packages
```

That warning is expected. It is not a failure.

### `minimal_publication` field allowlists

`sanitized_summary.json` permits only:

- schema version;
- test identifier and slot;
- classified `asset_key`, family, variant, transport, critical, publication profile, and `publication_safe`;
- flow type;
- asset type;
- evidence role;
- technical provider and consumer connector aliases;
- placeholder execution identifiers;
- phase0 through phase4 status.

`sanitized_manifest.json` permits only:

- schema version;
- artifact type;
- download status;
- byte count;
- SHA-256 algorithm;
- whether SHA-256 verification metadata was present;
- a withheld hash-value marker;
- confirmation that the payload is not included.

`validation_status.json` permits only:

- schema version;
- semantic-validation status and safe source classification;
- confirmation that payloads, phase environments, requests, responses, and real identifiers were excluded;
- confirmation that the private-payload hash value was withheld.

The package manifests use only their fixed inventory fields. `minimal_publication` inventory rows contain no source path and use `<run-id>` instead of the runtime suffix.

Every package also writes `package_status.json` (`publication_ready`, `publication_blockers`, per-slot inventory) and `slot_inventory.json`.

### XLSX boundary

`export_evidence_to_excel.py` projects `minimal_publication` slots through the same canonical model used by the bundle exporter. A single-slot Ingestion API workbook includes `Slot Map`, `Summary`, the classified slot sheet, `Raw JSON Index`, `Evidence Checklist`, and `Package Manifest`.

Those cells are restricted to explicit mappings from the canonical model. Delivery-only columns use `not_recorded` or `not_applicable`; the private payload hash is replaced by the withheld marker. The runtime suffix is used only to locate internal evidence and must not survive in the workbook filename, cells, sheet names, properties, defined names, ZIP metadata, or relationships.

Stable names are `ippcp_evidence_summary_<TIMESTAMP>.xlsx` and `ippcp_evidence_package_<TIMESTAMP>.zip`. Do not use `ippcp_t4_publication.xlsx`, `ippcp_t4_publication.zip`, or globs such as `ippcp_evidence_summary_*.xlsx`. Commands: [`tools/tools_README.md`](../tools/tools_README.md).

Before writing the file, the exporter audits the in-memory workbook. It then audits the serialized OOXML package and reloads it for a final structural check. The controls cover:

- visible, hidden, and `veryHidden` worksheets;
- hidden rows and columns;
- cells and formulas;
- comments and notes;
- hyperlinks;
- defined names;
- workbook and document properties;
- external relationships and links;
- macros and VBA;
- shared strings when present;
- custom XML and unexpected OOXML parts.

An unexpected OOXML part is rejected unless it belongs to the reviewed workbook structure. A `minimal_publication` workbook is eligible for publication only after this audit succeeds and a manual review is completed.

`standard` Excel sheets preserve intentional delivery suffixes, identifiers, paths, and hashes, so any package that includes them is an internal evidence artifact (`publication_ready=false`).

The `minimal_publication` ZIP allowlist remains JSON and text only. Enabling the workbook does not add an XLSX entry to that archive.

### Output classifications

- **`minimal_publication` sanitized bundle:** eligible for publication after manual review when `publication_ready=true`.
- **`minimal_publication` sanitized workbook:** eligible for publication after the full OOXML audit and manual review.
- **Complete or mixed package with any `standard_internal` slot:** internal. Do not send it externally.
- **Synthetic JSON example:** public, versioned structural documentation.

A public-safe workbook or bundle covering WFS/SPARQL would require an explicit future decision to change those assets' publication policy.

## Allowed artifact classes after sanitization

Only the following classes may be considered for demo or public use:

- phase and step status metadata;
- flow and asset type;
- abstract technical topology metadata;
- sanitized summary structure;
- sanitized manifest structure;
- byte count;
- SHA-256 algorithm and verification metadata;
- semantic validation result;
- placeholder execution identifiers;
- package inventory containing safe logical entry names;
- explanatory README content.

Every exported structure must have a field-level allowlist. Unknown fields are excluded. In strict publication mode, an unknown output field or archive entry is an error.

## Forbidden artifact classes

The following must never be included in a demo-visible or public evidence package:

- credentials or secret values;
- passwords;
- JWTs or JWT-like strings;
- API keys;
- raw `Authorization` or EDR authorization;
- full `phase*_env.sh` files;
- runtime environment directories;
- raw data-address requests or responses;
- raw Management API requests or responses;
- EDR response bodies;
- raw phase requests or response bodies;
- response previews;
- concrete internal, PRE, or POST hosts;
- local absolute filesystem paths;
- personal data;
- business-sensitive data;
- downloaded business payloads;
- source evidence paths;
- real run suffixes in public structures;
- real asset, contract, negotiation, agreement, or transfer identifiers.

Downloaded payload exclusion applies even when the payload is valid JSON and even when it contains no credential. Business data is outside the publication allowlist.

## Identifier replacement

Publication transforms execution identifiers into stable placeholders by meaning:

- `<run-id>`;
- `<asset-id>`;
- `<contract-definition-id>`;
- `<negotiation-id>`;
- `<agreement-id>`;
- `<transfer-process-id>`.

The exporter must not use a reversible mapping in a public package. A package inventory must use logical source classes rather than real local source paths.

Technical topology may use the reviewed diagram aliases:

- `CONN-CITYCOUNCIL` for the technical provider connector;
- `CONN-COMPANY` for the technical consumer connector.

These aliases describe connector topology. They do not redefine the functional actor roles in the end-user journey.

## Secret redaction

Redaction must occur before an artifact enters the publication staging area.

The publication check must reject:

- a non-redacted Ingestion API key;
- a non-redacted `X-Api-Key` value;
- a raw `Authorization` value;
- EDR authorization;
- JWT-like strings;
- password values;
- unapproved concrete hosts;
- absolute local paths;
- configured synthetic canary values.

Renaming a secret key is not sufficient when its value remains present. Copying a raw object and deleting a few known keys is also insufficient. Publication output must be constructed from allowlisted fields.

## Payload exclusion

The publication exporter must not read, stage, copy, summarize, or hash a downloaded business payload for the purpose of creating the public example package.

Permitted metadata may be read from an approved manifest or safe status structure. The publication package may state that a payload was excluded and that a non-zero byte count was recorded, but it must not include payload bytes or a preview.

## Cryptographic hashes

A cryptographic hash may be public only when:

- it does not enable access to a private payload;
- it does not disclose or materially fingerprint sensitive business data;
- its source and meaning are understood;
- publication has been explicitly approved.

The default public profile should withhold the value while retaining:

- the algorithm name;
- whether verification succeeded;
- a placeholder or explicit “withheld pending approval” marker.

Synthetic examples may use a clearly labelled synthetic hash.

## Manual publication review

Before publication, a reviewer must:

1. compare the package inventory with the profile allowlist;
2. inspect every archive entry;
3. validate every JSON structure against its field allowlist;
4. confirm that no payload, phase environment, request, response, preview, or source path is present;
5. run secret, JWT, authorization, host, path, identifier, and canary scans;
6. confirm that all identifiers are placeholders;
7. decide whether any hash value is approved;
8. confirm the intended distribution channel and audience;
9. record approval in an internal publication record.

Automated success does not replace this decision.

## Retention and rotation

Internal raw evidence, sanitized internal evidence, generated packages, and public examples have different retention needs.

- Raw evidence must follow the project’s controlled storage and retention rules.
- Temporary staging directories and generated archives must be removed after review unless retained in approved internal storage.
- Public examples should be versioned only when their structure remains useful and safe.
- A superseded public example should be removed or clearly versioned.
- Secret rotation does not make an old raw artifact publishable.
- Asset immutability means an Ingestion API credential change requires a new asset and execution; evidence from both executions remains subject to this policy.

Final retention duration and archive ownership remain project governance decisions.

## Relationship to the evidence model

`T1`–`T4` are exporter slots. Publication policy is attached to the classified asset.

- `ingestion_api_v2` uses `minimal_publication`.
- `csv_b2_legacy` is a legacy historical baseline and uses `standard` (`standard_internal`).
- `wfs_juntas`, `wfs_ciudad`, and `sparql` currently use `standard` (`standard_internal`).

CSV/B2 does not replace, and is not replaced by, Ingestion API v2. Historical T1–T3 assessment suffixes are selected only with `--preset legacy_assessment` or `--preset legacy_test3`.

## Related documentation

- [Evidence export CLI](../tools/tools_README.md)
- [Evidence tooling model](../tools/evidence_tooling.md)
- [Evidence and traceability](evidence-and-traceability.md)
- [Authentication](authentication.md)
- [Architecture](architecture.md)
- [Demo readiness checklist](demo/readiness-checklist.md)
