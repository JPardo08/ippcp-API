# SPARQL Flow

## Purpose

This guide defines the current SPARQL flow-specific configuration and operator checks. The common lifecycle is defined in [Execution phases](../execution-phases.md).

## Scope

- Flow version: `v2`, current and recommended.
- Transfer type: `HttpData-PULL`.
- Provider: city council connector.
- Consumer: company connector.
- Canonical response type: SPARQL results JSON.

## Upstream resource

The upstream resource is a public SPARQL query service. The provider publishes a complete query URL as an HTTP data address, and phase 4 materializes the result through the Data Plane.

Public documentation does not reproduce the concrete upstream host or raw result data. The repository asset configuration supplies the endpoint, encoded query, and result format.

## Canonical configuration

The current canonical configuration is:

```text
asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json
```

It declares:

- `type=HttpData`;
- `content_kind=json`;
- `extension=json`;
- `media_type=application/sparql-results+json`;
- an encoded SELECT query with a validation limit;
- an explicit URL parameter requesting `application/sparql-results+json`.

The result format must be part of the configured URL because the current `HttpData-PULL` path does not inject a SPARQL-specific `Accept` header.

## Flow-specific variables

Required:

| Variable | Value |
| --- | --- |
| `IPPCP_DATASPACE` | `ippcp` |
| `IPPCP_FLOW` | `consumo` |
| `IPPCP_FLOW_VERSION` | `v2` |
| `ASSET_CONFIG` | `asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json` |

No SPARQL-specific upstream credential is required for the current public resource. Do not source the Ingestion API environment.

Internally handled:

- phase 1 publishes the configured query URL as the provider data address;
- phase 1 exports the SPARQL result media type and JSON extension;
- phase 4 requires a non-empty syntactically valid JSON response;
- EDR retrieval and authorization candidates are handled by the common phase scripts.

Optional:

- `data/real/consumo/sparql/test_sparql_format_variants.sh` is a direct upstream format experiment, not part of phase0–phase4.

## Phase 1 behavior

Phase 1 publishes the canonical query and explicit JSON format without adding upstream authentication or `Accept` headers.

Changing the query or result format changes the upstream data address and therefore requires a new asset execution. Do not reuse a published asset to represent a different query.

## Current v2 execution

Run this block from the repository root:

```bash
run_sparql_flow() {
  local bash_bin download_file manifest_file
  bash_bin="${BASH_BIN:-$(command -v bash)}"

  unset IPPCP_DATASPACE_FILE IPPCP_DATASPACE_DIR IPPCP_FLOW_DIR
  unset SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL
  unset CD_ID VOCAB_ID ACCESS_POLICY_ID CONTRACT_POLICY_ID

  export IPPCP_DATASPACE=ippcp
  export IPPCP_FLOW=consumo
  export IPPCP_FLOW_VERSION=v2

  "${bash_bin}" scripts/phase0_context_smoke.sh || return 1

  source runtime/env/latest/phase0_env.sh
  export ASSET_CONFIG="asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json"
  "${bash_bin}" scripts/phase1_provider_publish.sh || return 1

  source runtime/env/latest/phase1_env.sh
  "${bash_bin}" scripts/phase2_consumer_negotiate.sh || return 1

  source runtime/env/latest/phase2_env.sh
  "${bash_bin}" scripts/phase3_transfer_edr.sh || return 1

  source runtime/env/latest/phase3_env.sh
  "${bash_bin}" scripts/phase4_save_download.sh || return 1

  download_file="downloads/assets/${ASSET_ID}/latest.${ASSET_EXTENSION:-json}"
  manifest_file="downloads/manifests/${ASSET_ID}/latest.manifest.json"

  test -s "${download_file}"
  jq -e '
    type == "object"
    and (.head | type == "object")
    and (.results | type == "object")
    and (.results.bindings | type == "array")
    and all(.results.bindings[]; type == "object")
  ' "${download_file}"
  jq -e \
    --arg suffix "${SUFFIX}" \
    --arg asset_id "${ASSET_ID}" \
    '.suffix == $suffix
      and .asset_id == $asset_id
      and (.bytes > 0)
      and (.sha256 | type == "string" and length == 64)' \
    "${manifest_file}"
}

run_sparql_flow
unset -f run_sparql_flow
```

Every phase sources the preceding phase environment before continuing. `ASSET_CONFIG` is set explicitly after phase 0 and before phase 1.

## Expected result

A successful phase 4 creates:

```text
evidencias/runs/<run_id>/phase4/40_data_response.json
downloads/assets/<asset_id>/<run_id>.json
downloads/assets/<asset_id>/latest.json
downloads/manifests/<asset_id>/<run_id>.manifest.json
downloads/manifests/<asset_id>/latest.manifest.json
```

The run-specific download and manifest, asset ID, and run metadata provide durable local traceability. `latest.json` and `latest.manifest.json` are mutable current-result conveniences, not stable backend integration contracts.

## Validation

HTTP 200 and generic JSON syntax are not sufficient. The canonical response must be a SPARQL Results JSON object with:

- a top-level `head` object;
- a top-level `results` object;
- a `results.bindings` array;
- object-valued binding entries.

The executable block applies these structural checks with `jq`.

Also verify:

- phase 4 is `ok` in `summary.json`;
- the manifest `suffix` and `asset_id` match the current execution;
- the manifest media type corresponds to SPARQL Results JSON;
- the manifest records a positive byte count and populated SHA-256;
- the bindings match the intended query semantics without publishing raw result data.

The phase 4 script validates non-empty JSON syntax. The guide's post-download `jq` expression adds the SPARQL Results structure check.

See [Evidence and traceability](../evidence-and-traceability.md) for durable evidence and publication rules.

## XML with HTTP 200 is a failure

Some SPARQL services return XML when no explicit result format is requested, even when the HTTP status is 200.

XML is not valid output for an asset declared as JSON:

1. phase 4 stores the attempted response internally;
2. `jq empty` rejects the XML body;
3. the response is not accepted as the material download;
4. phase 4 fails if no valid JSON attempt succeeds.

Do not relabel XML as `.json` or accept transport status as proof of the content contract. Use the canonical configuration with its explicit SPARQL Results JSON format.

## Flow-specific errors

### XML instead of JSON

Cause: a configuration without an explicit JSON result parameter, or an upstream service that ignored the requested format.

Action: confirm that `ASSET_CONFIG` points to the canonical `*_format_json.json` configuration. Inspect only sanitized response metadata when preparing evidence.

### HTTP 200 with an unexpected body

An HTML/XML error page or application message can still arrive with HTTP 200. Require:

- a non-empty file;
- valid JSON;
- the SPARQL Results structure described above.

### Valid JSON with the wrong structure

A generic JSON error object can pass `jq empty` but fail the semantic check. Review the encoded query, format parameter, and upstream response contract.

### Incorrect query or format

An invalid encoded query can produce a protocol error or an application-level response. A valid query with a non-JSON format can produce XML. Validate query and format together before publishing a new asset.

### Existing local output

If the run-specific target already exists with different content, phase 4 fails unless the operator deliberately uses the common `DOWNLOAD_FORCE=1` recovery control after verifying the run and destination.

## Legacy and non-current material

- `asset_configs/real/consumo/sparql/emisiones_sparql_limit10.json` is legacy/noncanonical because it omits the explicit JSON format and can return XML.
- `asset_configs/examples/emisiones_sparql.example.json` is a generic template, not the current validated IPPCP query.
- Direct curl scripts that rely on `Accept` are upstream experiments, not equivalent to the current Data Plane path.
- `v1` is legacy-supported and not used by the current block.
- `test3` and old workshop procedures are historical.

The legacy configuration remains in the repository for reproducibility; this guide does not remove or promote it.

## Related documentation

- [Architecture](../architecture.md)
- [Authentication](../authentication.md)
- [Execution phases](../execution-phases.md)
- [Evidence and traceability](../evidence-and-traceability.md)
