# Ingestion API Flow

## Purpose

This guide defines the current Ingestion API flow-specific configuration and operator checks. The common lifecycle is defined in [Execution phases](../execution-phases.md), and credential ownership is defined in [Authentication](../authentication.md).

## Scope

- Flow version: `v2`, current and recommended.
- Transfer type: `HttpData-PULL`.
- Provider: city council connector.
- Consumer: company connector.
- Available environment profile: PRE.
- Validation status: completed end-to-end in PRE through a phase 4 download and manifest.

PRE is the currently available profile for this configuration, not a universal deployment requirement. Other environments require their own validated asset configuration and local secret provisioning. Concrete hosts, run identifiers, UUIDs, hashes, and business data are intentionally excluded.

## Upstream resource

The upstream resource is a JSON Ingestion API exposed through the provider asset. The Data Plane performs an HTTP GET to that resource after validating the consumer's EDR authorization.

The upstream hop requires:

- `X-Api-Key`;
- `X-Provider-Id`.

These headers belong to the provider data address. They are not consumer request parameters.

## Flow-specific configuration

The current configuration is:

```text
asset_configs/real/ingesta/ingesta_api_pull_pre_api_key.json
```

It declares:

- `type=HttpData`;
- JSON content and `.json` output;
- `requires_api_key_header=true`;
- `requires_provider_id_header=true`.

The ignored local environment file is:

```text
data/real/ingesta/auth/ingesta_api_key.env
```

Create it from:

```text
data/real/ingesta/auth/ingesta_api_key.env.example
```

Do not commit the local file or place its values in commands, documentation, logs, screenshots, or evidence.

## Flow-specific variables

Required during phase 1:

| Variable | Requirement |
| --- | --- |
| `ASSET_CONFIG` | Must select `ingesta_api_pull_pre_api_key.json` |
| `INGESTA_API_KEY` | Non-empty local API key |
| `INGESTA_API_PROVIDER_ID` | Numeric provider identifier expected by the upstream application |

`INGESTA_API_PROVIDER_ID` belongs to the published asset configuration. It is not a Keycloak UUID.

Internally handled:

- phase 1 adds `header:X-Api-Key` and `header:X-Provider-Id` to the real provider data address;
- persisted phase 1 evidence replaces the API-key value with `<redacted>`;
- the API key is not exported through `phase1_env.sh`;
- phases 2–4 do not require either Ingestion API variable in the operator environment.

Optional:

- the direct PRE curl scripts can be used as an upstream preflight before starting the EdD execution.

## Authentication boundary

The asset does not contain an expiring upstream JWT. The API key is loaded immediately before phase 1 and stored in the provider connector's data address for the assessment.

The consumer connector and a future consumer backend do not receive this API key. They receive an EDR for the separate consumer-to-Data Plane hop. Phase 4 therefore runs normally without additional upstream-authentication flags.

See [Authentication](../authentication.md) for the complete boundary and persistence model.

### Evidence-profile rationale

This protected upstream boundary is why the additional validated T4 integration uses a separate evidence and publication profile. T4 covers the Ingestion API through `HttpData-PULL`; it does not replace the delivered T1 CSV-based ingestion baseline or the delivered T2 WFS and T3 SPARQL evidence flows.

The provider-side `X-Api-Key` and `X-Provider-Id` values stay inside the provider boundary. They are not public values, are not sent to the consumer, are not propagated through the EDR, and are not dynamically obtained by the evidence tools. They must not appear in evidence packages, workbooks, or public examples.

T4 therefore projects only the shared `minimal_publication` model through strict allowlists and sanitized-output rules. This reflects a stricter security and publication boundary, not lower validity or experimental status. Mixed T1–T4 outputs remain internal because T1–T3 preserve identifiers, paths, and hashes from the delivered evidence process.

See [Evidence and traceability](../evidence-and-traceability.md) and the [Evidence Publication Policy](../evidence-publication.md) for the export boundary.

## Phase 1 behavior

Phase 1:

1. validates the asset configuration;
2. requires a numeric provider ID and non-empty API key;
3. builds a temporary publication payload containing both upstream headers;
4. publishes the immutable asset and data address;
5. persists only redacted evidence;
6. exports non-secret execution state.

Changing the provider ID or rotating the API key requires publication of a new asset with a new execution identifier. Reusing the existing immutable asset would retain its previous data address.

## Optional direct upstream preflight

This preflight is separate from the phase0–phase4 pipeline. It validates the currently available PRE profile without publishing an asset:

```bash
run_ingestion_preflight() {
  source data/real/ingesta/auth/ingesta_api_key.env

  if ! bash data/real/ingesta/pre/curl_ingesta_api_pull_pre_base.sh; then
    unset INGESTA_API_KEY INGESTA_API_PROVIDER_ID
    return 1
  fi

  unset INGESTA_API_KEY INGESTA_API_PROVIDER_ID
}

run_ingestion_preflight
unset -f run_ingestion_preflight
```

The preflight succeeds only when the response is HTTP 200, non-empty, and valid JSON. Unconfirmed query-parameter experiments are excluded from the public flow.

## Current v2 execution

Run this block from the repository root. It sources the upstream secret only for phase 1 and removes it before negotiation:

```bash
run_ingestion_flow() {
  local bash_bin download_file manifest_file
  bash_bin="${BASH_BIN:-$(command -v bash)}"

  unset IPPCP_DATASPACE_FILE IPPCP_DATASPACE_DIR IPPCP_FLOW_DIR
  unset SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL
  unset CD_ID VOCAB_ID ACCESS_POLICY_ID CONTRACT_POLICY_ID

  export IPPCP_DATASPACE=ippcp
  export IPPCP_FLOW=ingesta
  export IPPCP_FLOW_VERSION=v2

  "${bash_bin}" scripts/phase0_context_smoke.sh || return 1

  source runtime/env/latest/phase0_env.sh
  source data/real/ingesta/auth/ingesta_api_key.env
  export ASSET_CONFIG="asset_configs/real/ingesta/ingesta_api_pull_pre_api_key.json"

  if ! "${bash_bin}" scripts/phase1_provider_publish.sh; then
    unset INGESTA_API_KEY INGESTA_API_PROVIDER_ID
    return 1
  fi
  unset INGESTA_API_KEY INGESTA_API_PROVIDER_ID

  source runtime/env/latest/phase1_env.sh
  "${bash_bin}" scripts/phase2_consumer_negotiate.sh || return 1

  source runtime/env/latest/phase2_env.sh
  "${bash_bin}" scripts/phase3_transfer_edr.sh || return 1

  source runtime/env/latest/phase3_env.sh
  "${bash_bin}" scripts/phase4_save_download.sh || return 1

  download_file="downloads/assets/${ASSET_ID}/latest.${ASSET_EXTENSION:-json}"
  manifest_file="downloads/manifests/${ASSET_ID}/latest.manifest.json"

  test -s "${download_file}"
  jq empty "${download_file}"
  jq -e \
    --arg suffix "${SUFFIX}" \
    --arg asset_id "${ASSET_ID}" \
    '.suffix == $suffix
      and .asset_id == $asset_id
      and (.bytes > 0)
      and (.sha256 | type == "string" and length == 64)' \
    "${manifest_file}"
}

run_ingestion_flow
unset -f run_ingestion_flow
```

Every phase sources the preceding phase environment before continuing. `ASSET_CONFIG` is set explicitly before phase 1.

## Expected result

A successful phase 4 creates:

```text
evidencias/runs/<run_id>/phase4/40_data_response.json
downloads/assets/<asset_id>/<run_id>.json
downloads/assets/<asset_id>/latest.json
downloads/manifests/<asset_id>/<run_id>.manifest.json
downloads/manifests/<asset_id>/latest.manifest.json
```

The run-specific download and manifest, linked by asset ID and run metadata, provide durable local traceability. `latest.json` and `latest.manifest.json` are mutable convenience outputs for the current local result; they are not stable backend integration contracts.

## Validation

Required acceptance checks:

- phase 4 completed successfully in `summary.json`;
- the downloaded file exists and is non-empty;
- `jq empty` accepts the downloaded JSON;
- the manifest identifies the current `SUFFIX` and `ASSET_ID`;
- manifest byte count is greater than zero;
- manifest SHA-256 is populated;
- no API key or EDR authorization appears in persisted evidence.

The canonical scripts validate JSON syntax but do not impose a business-specific Ingestion API response schema. If an integration requires particular fields, add that acceptance criterion outside the generic flow without publishing business data.

See [Evidence and traceability](../evidence-and-traceability.md) for durable evidence rules.

## Flow-specific errors

### Missing or invalid provider configuration

- Missing `INGESTA_API_KEY`: source the ignored API-key environment before phase 1.
- Missing `INGESTA_API_PROVIDER_ID`: provision the provider identifier for the selected upstream profile.
- Non-numeric provider ID: use the numeric application identifier, not a Keycloak identifier.
- Duplicate header supplied through an extra-header variable: remove it; phase 1 owns both canonical header fields.

### Upstream access failure

- HTTP 401 during direct preflight usually indicates a missing, invalid, or unauthorized API key.
- A missing-provider message indicates that `X-Provider-Id` was not supplied or was invalid.
- An empty or non-JSON response fails the preflight and phase 4 acceptance criteria even if transport succeeded.

### Publication conflict

An HTTP 409 during phase 1 indicates that an object with the derived identifier already exists. Start a new execution and publish a new asset rather than trying to mutate an existing asset data address.

### Phase 4 failure

Phase 4 retrieves the EDR again and handles EDR authorization candidates internally. Do not add the upstream API key to the consumer request and do not enable the historical upstream JWT route.

Review the redacted phase 4 attempt summary and `summary.json`; do not inspect or publish raw authorization material.

## Legacy and non-current material

- `ingesta_api_pull_pre.json` is superseded by the API-key configuration for the current PRE profile.
- Unvalidated production-profile configurations are excluded from the current public flow.
- B2/CSV/InesDataStore remains the delivered T1 evidence baseline and is not this `HttpData-PULL` flow.
- Legacy upstream-authentication helpers and phase 4 upstream-authentication flags are excluded.
- `v1` is legacy-supported and not used by the recommended block.
- `test3` and old workshop procedures are historical.

## Related documentation

- [Architecture](../architecture.md)
- [Authentication](../authentication.md)
- [Execution phases](../execution-phases.md)
- [Evidence and traceability](../evidence-and-traceability.md)
