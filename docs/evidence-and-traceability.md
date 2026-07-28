# Evidence and Traceability

## Purpose

This document is the canonical source for run identification, generated artifacts, manifests, and evidence safety.

## Run identifier

The functional concept is `run_id`. The current scripts implement it through the `SUFFIX` environment variable.

```text
run_id = SUFFIX
```

`SUFFIX` is generated when a new execution is loaded without existing phase state. It is reused when the operator sources a phase environment from that execution.

The same value links:

- connector object identifiers derived during publication;
- phase environment files;
- the run evidence directory;
- `summary.json`;
- materialized asset downloads;
- download manifests;
- exported evidence records.

All artifacts for one execution must use the same value. Mixing phase environments from different runs breaks traceability even if the underlying connector resources still exist.

## Execution identifiers

The current shell variables map to the conceptual identifiers as follows:

| Concept | Current variable | Created or resolved in | Purpose |
| --- | --- | --- | --- |
| `run_id` | `SUFFIX` | Initial environment load | Correlates the complete execution |
| `assetId` | `ASSET_ID` | Phase 1 | Identifies the published asset |
| `contractDefinitionId` | `CD_ID` | Phase 1 | Identifies the provider contract definition |
| `negotiationId` | `NEG_ID` | Phase 2 | Identifies the contract negotiation |
| `agreementId` | `AGREEMENT_ID` | Phase 2 | Identifies the resulting agreement |
| `transferProcessId` | `TRANSFER_ID` | Phase 3 | Identifies the transfer and EDR lookup |

Additional provider-side identifiers can include:

- `VOCAB_ID`;
- `ACCESS_POLICY_ID`;
- `CONTRACT_POLICY_ID`.

These support provider administration, evidence correlation, and potential future cleanup. They are not substitutes for the core negotiation and transfer identifiers.

Catalog-specific identifiers such as `PROVIDER_PARTICIPANT_ID`, `OFFER_POLICY_ID`, and `CATALOG_ASSET_ID` record what the consumer selected. They can be useful when diagnosing catalog or policy mismatches.

## Evidence structure

```text
evidencias/runs/<run_id>/
  phase0/
  phase1/
  phase2/
  phase3/
  phase4/
  phase0_env.sh
  phase1_env.sh
  phase2_env.sh
  phase3_env.sh
  summary.json
```

The shared runtime initializes directories for alternate historical paths as well, but their presence does not prove that those paths ran. Phase status in `summary.json` and the corresponding artifacts are the execution record.

Each control-plane request normally produces:

- a JSON response or sanitized diagnostic;
- a sibling `.http` file containing the HTTP status;
- a step entry in `summary.json`.

Phase environment files are operational hand-off state. They are retained internally for traceability but are excluded from public evidence packages.

## Artifacts by phase

### Phase 0: context and access

Phase 0 records:

- execution context and selected flow;
- redacted provider JWT claims;
- redacted consumer JWT claims;
- provider connector smoke response and status;
- consumer connector smoke response and status.

JWT claim artifacts contain decoded non-secret claims, not the token string.

### Phase 1: provider publication

Phase 1 records the publication sequence:

- vocabulary operation when applicable;
- access-policy operation;
- contract-policy operation;
- asset publication;
- asset retrieval;
- contract-definition publication and listing;
- provider self-catalog request;
- catalog asset match;
- sanitized asset metadata and data address.

For Ingestion API assets, persisted data-address evidence must contain:

```text
header:X-Api-Key = <redacted>
```

The numeric provider identifier can remain in internal evidence, but publication still requires an explicit assessment of whether it is appropriate for a public package.

### Phase 2: consumer negotiation

Phase 2 records:

- remote catalog request and response;
- selected participant, asset, and offer-policy identifiers;
- negotiation creation;
- negotiation state polling;
- finalized negotiation and agreement identifiers;
- agreement retrieval and listing.

### Phase 3: transfer and EDR

Phase 3 records:

- transfer creation;
- transfer state polling and final state;
- redacted EDR data address;
- EDR field-name diagnostics without authorization values;
- EDR retrieval source;
- the normal decision to defer material data consumption to phase 4.

Raw EDR authorization is runtime-only material and is not evidence.

### Phase 4: download and verification

Phase 4 records:

- consumer re-authentication claims;
- a newly retrieved, redacted EDR data address;
- internal authentication-attempt labels without credential values;
- HTTP result metadata;
- the accepted response artifact;
- byte count;
- SHA-256;
- run-specific and latest download manifests.

Phase 4 does not create a phase environment file.

See [Execution phases](execution-phases.md) for the operational inputs and outputs of each phase.

## `summary.json`

`summary.json` is the machine-readable run index. It is created atomically with:

- `suffix`;
- `ds_name`;
- `started_at`;
- a `phases` object.

Each phase contains:

- a phase-level status;
- an ordered list of steps.

Each step contains:

- a stable step identifier;
- `ok`, `fail`, or `skipped` status as applicable;
- timestamp;
- non-secret metadata such as HTTP status, connector object identifier, final state, or artifact reference.

The summary is updated throughout execution. A directory or artifact existing on disk does not by itself prove successful completion; the phase status and expected terminal step must also be present.

The summary is a control index, not a container for raw HTTP payloads, tokens, passwords, or API keys.

## Runtime environments

Phase environments are written both inside the run directory and under `runtime/env/latest/`. The `latest` directory is operational convenience only; it is not an evidence archive.

Run-specific phase files preserve the IDs needed to continue or audit an execution. `runtime/env/backups/` can retain displaced convenience files when a newer `SUFFIX` is exported.

Before resuming:

1. read `SUFFIX` from the selected run;
2. confirm that every phase file uses that value;
3. confirm prerequisite phase status in `summary.json`;
4. confirm that inherited IDs agree with the summary and artifacts;
5. source only the next required phase state.

## Downloads and manifests

Successful phase 4 execution creates:

```text
downloads/assets/<asset_id>/<run_id>.<extension>
downloads/assets/<asset_id>/latest.<extension>
downloads/manifests/<asset_id>/<run_id>.manifest.json
downloads/manifests/<asset_id>/latest.manifest.json
```

The run-specific files are the immutable traceability targets. `latest.*` files are mutable convenience copies and must not be used alone to identify historical evidence.

The manifest records:

- `suffix`;
- asset, agreement, and transfer identifiers;
- safe EDR URL information;
- content kind, extension, and media type;
- source evidence artifact;
- run-specific and latest download paths;
- byte count;
- HTTP status;
- SHA-256;
- creation time;
- copy action;
- non-secret EDR authentication candidate label.

The scripts write the manifest to:

- the run-specific download manifest;
- the latest download manifest;
- `phase4/download_manifest.json`;
- `phase4/download_summary.json`.

The SHA-256 value binds the manifest to the materialized bytes. Matching hashes prove byte-for-byte equality between compared files; they do not independently prove source authenticity or authorization.

## Delivered and additional validation evidence

The evidence labels describe delivered test baselines and additional validation. They do not redefine the recommended architecture.

| Test | Evidence meaning | Status |
| --- | --- | --- |
| T1 | CSV-based ingestion through the B2/InesDataStore flow | Delivered baseline evidence; preserved, not recommended for new integration |
| T2 | WFS data exchange | Delivered evidence |
| T3 | SPARQL data exchange | Delivered evidence |
| T4 | Ingestion API `v2` through `HttpData-PULL`, `X-Api-Key`, and `X-Provider-Id` | Additional validated integration |

T4 does not replace, reinterpret, or relabel T1. T1 remains the delivered CSV-based baseline.

The current evidence export configuration supports T1, T2, and T3 with their existing delivery behavior. It also registers T4 as an optional `minimal_publication` profile. T4 is not selected by default and is not delivered assessment evidence.

### Why T4 uses a separate profile

T1 is the delivered CSV-based ingestion baseline, while T2 and T3 are the delivered WFS and SPARQL evidence flows. T4 validates a different protected integration: the Ingestion API through `HttpData-PULL`.

The Ingestion API is not an unauthenticated public endpoint. Provider Data Plane access to the upstream API requires provider-side `X-Api-Key` and `X-Provider-Id` values. These operational values remain inside the provider boundary. They are invisible to the consumer, are not propagated through the EDR, and must never enter an evidence package, workbook, or public example. The evidence tools do not obtain or transport the API key.

T4 therefore uses the shared `minimal_publication` model, strict field and artifact allowlists, and separate sanitized-output rules. This separation reflects a stricter security and publication boundary; it does not make T4 less valid, secondary, or experimental.

Mixed T1–T4 outputs remain internal because T1–T3 intentionally preserve identifiers, paths, and hashes from the delivered evidence process.

## T4 evidence export

### Shared runtime selection

The versioned T4 profile has an empty suffix. The exporter never guesses a run and never selects a T4 evidence directory automatically.

Both `package_evidence_bundle.py` and `export_evidence_to_excel.py` use the same selection behavior:

- default invocation: T1, T2, and T3 only;
- `--only-tests T4` without a runtime suffix: fails before reading evidence;
- `--only-tests T4 --tests T4=<runtime-suffix>`: T4 only;
- `--tests T4=<runtime-suffix>` without `--only-tests`: T1 through T4, preserving the existing override semantics.

The suffix is internal operational input used only to locate evidence. It is replaced by placeholders and must not appear in T4 cells, filenames, properties, relationships, package manifests, or public inventories.

### Sanitized T4 bundle

Generate a T4-only bundle with:

```bash
: "${T4_SUFFIX:?Set T4_SUFFIX to the local T4 runtime suffix}"

python3 tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --only-tests T4 \
  --tests "T4=${T4_SUFFIX}" \
  --output reports/exports/t4/ippcp_t4_publication.zip \
  --strict
```

The T4 ZIP contains only:

- `README_PACKAGE.txt`;
- `package_manifest.json`;
- `package_manifest.csv`;
- `T4_ingestion_api/sanitized_summary.json`;
- `T4_ingestion_api/sanitized_manifest.json`;
- `T4_ingestion_api/validation_status.json`.

The profile constructs these structures from field allowlists. It does not copy full source objects. The T4-only bundle is eligible for publication after manual review. A mixed T1–T4 bundle is internal and strict publication mode may reject it.

### Sanitized T4 workbook

Generate a T4-only workbook with:

```bash
: "${T4_SUFFIX:?Set T4_SUFFIX to the local T4 runtime suffix}"

python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --only-tests T4 \
  --tests "T4=${T4_SUFFIX}" \
  --export-dir reports/exports/t4 \
  --strict
```

The stable output name is `ippcp_t4_publication.xlsx`. It contains `Summary`, `Raw JSON Index`, `Evidence Checklist`, `Package Manifest`, and `T4_ingestion_api`. T4 uses the existing workbook columns where applicable and uses `not_recorded` or `not_applicable` where delivery-only fields cannot be published.

The workbook and bundle project the same canonical allowlisted T4 model. The workbook adds no raw evidence fields. It is eligible for publication only after its automated OOXML audit succeeds and the workbook passes manual review.

Using `--tests T4=<runtime-suffix>` without `--only-tests` creates an eight-sheet mixed T1–T4 workbook. That workbook is internal because T1–T3 intentionally retain delivery suffixes, identifiers, paths, and hashes. It is not a fully public-safe artifact.

### Shared exclusions

If an allowlisted semantic-validation metadata file is not present, `validation_status.json` reports `not_recorded`. The exporter does not inspect the downloaded payload or infer semantic success from phase4 completion.

The profile excludes:

- downloaded payloads and previews;
- phase environment files;
- raw phase requests and responses;
- raw Management API responses;
- data-address content;
- EDR and authorization content;
- source evidence paths;
- real suffixes and execution identifiers;
- concrete hosts and local paths.

The source payload SHA-256 value is withheld by default. The sanitized manifest retains the algorithm and verification metadata. Publication of a real hash requires the approval defined in the [Evidence Publication Policy](evidence-publication.md).

A generated structural example is available under [Synthetic T4 evidence example](../examples/evidence/t4-ingestion-api/README.md). It was produced from a synthetic fixture and is not raw output from the validated PRE run.

## Internal and publishable evidence

### Internal evidence

Internal evidence can retain operational detail required for diagnosis and audit, including:

- concrete run and connector object identifiers;
- assessment-environment HTTP responses;
- connector names;
- provider identifiers;
- non-public endpoints;
- run-specific manifests and hashes;
- material downloads when access policy permits.

Internal does not mean unredacted. Secrets and authorization values must still be removed.

### Publishable evidence

An artifact is publishable only after explicit sanitization and approval. A public package should use:

- public connector aliases;
- repository-relative paths;
- sanitized identifiers where concrete values are unnecessary;
- redacted data addresses;
- minimal response excerpts or metadata instead of raw business data;
- package manifests listing included and excluded files;
- hashes calculated after sanitization and packaging.

Public documentation can state that a flow completed end-to-end in PRE with a successful data response and verified manifest. It must not expose the concrete validation run unless that run has been separately sanitized and approved.

## Sanitized validation example

A safe public statement is:

> The current v2 Ingestion API flow was validated end-to-end in PRE. Phase 4 returned a successful data response and generated a manifest with a verified SHA-256 hash.

This statement intentionally omits the run identifier, connector object identifiers, hash value, hosts, organization data, raw response, and authorization material.

## Evidence safety

No persisted or packaged evidence may contain:

- passwords;
- API-key values;
- raw JWTs or Bearer tokens;
- EDR authorization;
- OAuth client secrets;
- storage credentials;
- sensitive URL query parameters.

Public evidence must additionally exclude or sanitize:

- local filesystem paths;
- internal hostnames;
- private connector names;
- concrete run and object identifiers unless approved;
- raw business data;
- ignored environment files.

The Ingestion API key must appear only as `<redacted>` in persisted JSON evidence.

Sensitive filenames such as `*.sensitive.json` and `*.secret.json`, phase environment files, raw request bodies, and runtime credential files are excluded by the current evidence tooling. The tooling also scans known dangerous JSON keys, JWT-like values, API-key headers, and local paths.

Automated scanning is a safeguard, not publication approval. New credential fields, binary content, screenshots, archives, and business payloads require manual review.

## Evidence integrity checks

Before treating a run as complete:

1. verify a single `SUFFIX` across summary, phase files, downloads, and manifests;
2. verify all expected phase statuses are `ok`;
3. verify core identifiers form one publication-negotiation-transfer chain;
4. verify HTTP status artifacts agree with summary metadata;
5. recompute the download SHA-256 and compare it with the run-specific manifest;
6. verify the run-specific file rather than relying only on `latest.*`;
7. scan every candidate artifact for secrets and local paths;
8. review the final package manifest and exclusions.

## Related documentation

- [Evidence Publication Policy](evidence-publication.md)
- [Execution phases](execution-phases.md)
- [Backend integration](backend-integration.md)
- [Authentication](authentication.md)
- [Architecture](architecture.md)
