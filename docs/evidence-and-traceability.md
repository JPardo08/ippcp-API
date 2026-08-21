# Evidence and Traceability

This is a reference document. Practical evidence commands from a completed workshop run are in [workshop.md](workshop.md).

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

## Evidence slots and asset classification

T1, T2, T3, and T4 are presentation slots. They are not asset types.

```text
run  ->  asset classification
asset  ->  critical / publication_profile / publication_safe
```

`--tests SLOT=SUFFIX` selects exactly those slots. The tool classifies each run from `summary.json`, asset metadata, phases, transfer type, and media type. Slot order is arbitrary.

Do not treat T1 as CSV, T2 as WFS, T3 as SPARQL, or T4 as Ingestion API. A COMPLETE example may place Ingestion API in T1 and SPARQL in T4; a SINGLE example may place Ingestion API in T3. `--only-tests` is a compatibility filter. It does not invent slots and is not the Golden Path for Ingestion API.

Historical delivered assessment evidence is selected with `--preset legacy_assessment`. That preset still occupies slots; assets are classified from each run. CSV/B2 remains a preserved baseline and is not the current workshop path.

### Publication profiles

Publication policy is a property of the classified asset, not of the slot id:

- `minimal_publication` → `publication_safe=true` (current Ingestion API v2 asset);
- `standard` → `publication_safe=false` (current WFS, SPARQL, and legacy CSV/B2 assets).

```text
package.publication_ready = all included slots are publication_safe
```

The Ingestion API is not an unauthenticated public endpoint. Provider Data Plane access to the upstream API requires provider-side `X-Api-Key` and `X-Provider-Id` values. These operational values remain inside the provider boundary. They are invisible to the consumer, are not propagated through the EDR, and must never enter an evidence package, workbook, or public example.

A package that includes any `standard` asset is not publication-ready. A SINGLE package that includes only the Ingestion API v2 asset can be publication-ready after review.

Operator commands: [workshop.md](workshop.md). Tool semantics: [tools/evidence_tooling.md](../tools/evidence_tooling.md) and [tools/tools_README.md](../tools/tools_README.md).

### Shared exclusions

If an allowlisted semantic-validation metadata file is not present, `validation_status.json` reports `not_recorded`. The exporter does not inspect the downloaded payload or infer semantic success from phase 4 completion.

The `minimal_publication` profile excludes:

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

A generated structural example is available under [Synthetic evidence example](../examples/evidence/t4-ingestion-api/README.md). It was produced from a synthetic fixture and is not raw output from a validated PRE run. The directory name is historical; current tooling names archive entries `{SLOT}_{sheet_slug}`.

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

- [Workshop](workshop.md)
- [Evidence Publication Policy](evidence-publication.md)
- [Execution phases](execution-phases.md)
- [Backend integration](backend-integration.md)
- [Authentication](authentication.md)
- [Architecture](architecture.md)
