# Demo Readiness Checklist

## Purpose

Use this checklist before approving an IPPCP demonstration. A checked item means the responsible reviewer has verified the condition for the selected demo environment and variant.

The checklist does not establish formal KPI or assessment compliance. It verifies observable readiness for the public-safe technical demonstration described in the [Final demo guide](final-demo.md).

## Functional readiness

- [ ] The use case and business stage are confirmed.
- [ ] Functional and technical stakeholders are identified by role.
- [ ] Provider, consumer, presenter/operator, and functional-speaker responsibilities are confirmed.
- [ ] One primary validated demo variant is selected: Ingestion API v2, WFS, or SPARQL JSON.
- [ ] The selected variant matches the intended audience, demo objective, available environment, and desired business narrative.
- [ ] The expected business result is agreed and can be explained without sensitive payloads.
- [ ] The distinction between business Phase A–C and technical `phase0`–`phase4` is ready to explain.
- [ ] Planned and out-of-scope capabilities are ready to explain accurately.
- [ ] Phase C is not presented as technically validated.

## Environment readiness

- [ ] The intended dataspace profile is explicitly selected.
- [ ] Provider and consumer connector base configuration is correct for that profile.
- [ ] `IPPCP_FLOW_VERSION=v2` is selected.
- [ ] The required flow is selected: `ingesta` for Ingestion API or `consumo` for WFS/SPARQL.
- [ ] Provider EdD credentials are available securely through the expected ignored local file.
- [ ] Consumer EdD credentials are available securely through the expected ignored local file.
- [ ] Flow-specific secrets are available securely only when required.
- [ ] For Ingestion API, the API key and provider identifier can be loaded immediately before phase1 and removed from the environment immediately afterward.
- [ ] The currently available PRE profile is reachable.
- [ ] No statement or presentation assumes that PRO/POST has been validated.
- [ ] Required local tools and a supported Bash version are available as described in [Getting Started](../getting-started.md).

## Flow readiness

- [ ] The phase0 smoke test succeeds for provider and consumer connector roles.
- [ ] The selected `ASSET_CONFIG` matches the intended variant.
- [ ] The selected asset identifier is unique for the planned run.
- [ ] Phase1 publishes the asset and contract definition successfully.
- [ ] Phase2 obtains a valid agreement; a display state alone is not accepted without the agreement identifier.
- [ ] Phase3 creates or resumes the intended transfer and resolves an EDR.
- [ ] Phase4 materializes a non-empty download through the Data Plane.
- [ ] The complete run uses one consistent `run_id`/`SUFFIX`.
- [ ] Ingestion API semantic validation confirms non-empty valid JSON.
- [ ] WFS semantic validation confirms valid GeoJSON with the expected `FeatureCollection` structure.
- [ ] SPARQL semantic validation confirms SPARQL Results JSON with `head` and `results.bindings`.
- [ ] Only the semantic check for the selected primary variant is presented as the live result.

## Evidence readiness

- [ ] `summary.json` records the expected phase statuses.
- [ ] Run-specific artifacts exist under one correlated execution.
- [ ] Provider asset and contract-definition identifiers are present internally.
- [ ] Consumer negotiation, agreement, and transfer identifiers are present internally.
- [ ] The phase4 manifest references the intended materialized result.
- [ ] The recorded byte count is non-zero and matches the selected result.
- [ ] SHA-256 verification succeeds.
- [ ] Any screenshot intended for display is redacted and approved.
- [ ] Any prepared output is sanitized and approved.
- [ ] No raw password, API key, JWT, EDR authorization, or credential file is included.
- [ ] No raw `phase*_env.sh` file is displayed or published.
- [ ] CSV/B2/InesDataStore is described as a legacy historical baseline, not the current Golden Path.
- [ ] Ingestion API v2 is described as the current HttpData-PULL ingestion validation, with `minimal_publication` attached to the asset rather than to slot T4.
- [ ] T1–T4 in exporter commands are described as slots, not as fixed asset types.
- [ ] An export uses explicit `--tests SLOT=SUFFIX` or `--preset`; no silent default slot set.
- [ ] `package_evidence_bundle.py` and `export_evidence_to_excel.py` use the same selection semantics.
- [ ] A publication-ready Ingestion API bundle uses `--tests` with that run in any slot, `--strict`, and has `publication_ready=true`.
- [ ] A `minimal_publication` archive contains only the allowlisted summary, manifest metadata, validation status, README, `package_status.json`, `slot_inventory.json`, and package inventories.
- [ ] Every `minimal_publication` JSON structure passes its field-level allowlist.
- [ ] A `minimal_publication` workbook uses deterministic `ippcp_evidence_summary_<TIMESTAMP>.xlsx` naming and passes the complete in-memory and serialized OOXML audit.
- [ ] Runtime suffixes of `minimal_publication` slots are absent from workbook cells, names, properties, relationships, and package metadata.
- [ ] Any package with `publication_ready=false` is classified as internal and is not sent externally.
- [ ] No XLSX file has been added to the `minimal_publication` ZIP allowlist.
- [ ] The [synthetic Ingestion API example](../../examples/evidence/t4-ingestion-api/README.md) is identified as structural documentation, not raw validation evidence.

## Presentation readiness

- [ ] The canonical architecture diagram is available and legible.
- [ ] The diagram is described as a high-level functional and infrastructure view, not an exhaustive EDC sequence.
- [ ] `CONN-CITYCOUNCIL` is identified as the provider connector and `CONN-COMPANY` as the consumer connector.
- [ ] Municipal application Keycloak and EdD Keycloak are explained as separate boundaries.
- [ ] The [Project and use-case rationale](project-justification.md) has been reviewed.
- [ ] The [End-user journey](end-user-journey.md) has been reviewed.
- [ ] The presenter sequence has been rehearsed using the selected flow guide.
- [ ] The target duration has been agreed.
- [ ] Technical and functional speakers are assigned by role.
- [ ] Expected technical, security, business-value, and limitation questions have been reviewed.
- [ ] Backup screenshots are available when produced and approved.
- [ ] A backup recording is available only when produced and approved.

## Contingency readiness

- [ ] A previously validated fallback run exists for the selected primary variant.
- [ ] At least one alternative validated flow is identified when its environment can be prepared safely.
- [ ] Offline sanitized evidence is available when it has been reviewed and approved.
- [ ] The presenter can distinguish a live failure from a previously validated result.
- [ ] The stop condition for avoiding secret exposure is understood.
- [ ] `PHASE2_FORCE=1` is used only when a new negotiation is intentionally required.
- [ ] `PHASE3_RESUME=1` is used only to resume EDR retrieval for the existing transfer.
- [ ] `PHASE3_FORCE=1` is used only when a new transfer is intentionally required.
- [ ] `PHASE3_RESUME=1` and `PHASE3_FORCE=1` are never combined.
- [ ] `DOWNLOAD_FORCE=1` is used only after checking run identity and the existing download.
- [ ] Any rollback or reset explanation is limited to controls actually implemented in [Troubleshooting](../troubleshooting.md).
- [ ] No automated provider cleanup or complete distributed rollback is claimed.

## Publication readiness

- [ ] No credentials or secret values are present.
- [ ] No internal or concrete connector hosts are present.
- [ ] No personal data is present.
- [ ] No raw evidence is present.
- [ ] No real run identifier, UUID, or hash is presented as public example data.
- [ ] No business-sensitive payload is present.
- [ ] No phase environment, raw request, raw response, preview, data-address content, or source path is present.
- [ ] Any cryptographic hash value has explicit publication approval; otherwise the value is withheld.
- [ ] The [Evidence Publication Policy](../evidence-publication.md) has been applied and manually reviewed.
- [ ] Any `minimal_publication` workbook has passed its automated OOXML audit and a separate manual workbook review.
- [ ] A package with `publication_ready=false` is not presented as a public-safe artifact.
- [ ] All local links and referenced repository paths resolve.
- [ ] All public-candidate text is in English.
- [ ] Licensing and acknowledgements have been checked against the repository [LICENSE](../../LICENSE).
- [ ] Public, internal, legacy-supported, and historical classifications have been reviewed.
- [ ] No `docs/internal` or `docs/archive` material is exposed by the demo navigation.
- [ ] Every displayed or packaged artifact has explicit publication approval.

## Final go/no-go

### Go criteria

- [ ] Every blocking item above is complete for the selected primary variant.
- [ ] The primary variant has passed a recent readiness run.
- [ ] The live sequence and contingency transition have been rehearsed.
- [ ] Public-safety review has passed.
- [ ] Functional and technical presenters agree on the claims and limitations.

### No-go criteria

Mark **No-Go** if any of these conditions applies:

- [ ] No primary validated variant has been selected.
- [ ] Required credentials or environment access cannot be prepared securely.
- [ ] Phase0 readiness fails and no approved validated fallback is available.
- [ ] Semantic validation or evidence integrity fails.
- [ ] The material to be shown has not passed publication review.
- [ ] The presentation would require claiming a planned or out-of-scope capability as validated.

### Decision

- [ ] **Go**
- [ ] **No-Go**

Record the decision, selected variant, responsible roles, and review time in the private operational record, not in the public documentation package.
