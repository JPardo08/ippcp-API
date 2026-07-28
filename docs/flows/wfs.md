# WFS Flow

## Purpose

This guide defines the current WFS flow-specific configuration and operator checks. The common lifecycle is defined in [Execution phases](../execution-phases.md).

## Scope

- Flow version: `v2`, current and recommended.
- Transfer type: `HttpData-PULL`.
- Provider: city council connector.
- Consumer: company connector.
- Response type: GeoJSON.

## Upstream resource

The upstream resource is a public WFS `GetFeature` service. The provider publishes the selected request URL as an HTTP data address, and phase 4 materializes the response through the Data Plane.

The current asset configurations request WFS 2.0.0 GeoJSON and limit the upstream response for validation. Public documentation does not reproduce the concrete upstream host. The selected repository configuration supplies it.

## Current validated configurations

Two current validated layers are available:

```text
asset_configs/real/consumo/wfs/emisiones_wfs_ciudad_geojson.json
asset_configs/real/consumo/wfs/emisiones_wfs_juntas_geojson.json
```

Select the configuration according to the required resource:

| Resource | Configuration | Difference |
| --- | --- | --- |
| City aggregate | `emisiones_wfs_ciudad_geojson.json` | Publishes the city-level aggregate layer |
| District-board aggregate | `emisiones_wfs_juntas_geojson.json` | Publishes the district-board layer |

Neither layer has priority over the other. Both use:

- `type=HttpData`;
- `content_kind=json`;
- `extension=json`;
- `media_type=application/json`;
- an upstream `outputFormat=application/json` request parameter.

They differ in asset slug, WFS layer name, descriptive metadata, and keywords.

The explicit upstream output format is required because phase 4 does not add a WFS-specific `Accept` header.

## Flow-specific variables

Required:

| Variable | Value |
| --- | --- |
| `IPPCP_DATASPACE` | `ippcp` |
| `IPPCP_FLOW` | `consumo` |
| `IPPCP_FLOW_VERSION` | `v2` |
| `ASSET_CONFIG` | Exactly one of the two current validated WFS configurations |

No WFS-specific upstream credential is required. Do not source the Ingestion API environment and do not set `INGESTA_API_KEY` or `INGESTA_API_PROVIDER_ID`.

Internally handled:

- the selected configuration's `base_url` becomes the provider asset data address;
- phase 1 exports the expected content kind, extension, and media type;
- phase 4 validates non-empty JSON syntax before accepting a response;
- EDR authorization candidates are handled by the common phase scripts.

Optional:

- the repository's direct WFS curl scripts can be used to test upstream availability, but they are not part of the EdD phase pipeline.

## Phase 1 behavior

Phase 1 publishes the selected WFS URL without upstream authentication headers. It derives a different `ASSET_ID` from each configuration's asset slug, so city and district-board executions remain distinguishable.

Do not pass the GML example or an InesDataStore configuration to this flow. The current validated acceptance contract is GeoJSON.

## Current v2 execution

Run this block from the repository root. Replace the resource placeholder with `ciudad` or `juntas`:

```bash
run_wfs_flow() {
  local bash_bin download_file manifest_file
  bash_bin="${BASH_BIN:-$(command -v bash)}"

  unset IPPCP_DATASPACE_FILE IPPCP_DATASPACE_DIR IPPCP_FLOW_DIR
  unset SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL
  unset CD_ID VOCAB_ID ACCESS_POLICY_ID CONTRACT_POLICY_ID

  export IPPCP_DATASPACE=ippcp
  export IPPCP_FLOW=consumo
  export IPPCP_FLOW_VERSION=v2

  case "${WFS_RESOURCE}" in
    ciudad)
      export ASSET_CONFIG="asset_configs/real/consumo/wfs/emisiones_wfs_ciudad_geojson.json"
      ;;
    juntas)
      export ASSET_CONFIG="asset_configs/real/consumo/wfs/emisiones_wfs_juntas_geojson.json"
      ;;
    *)
      echo "Set WFS_RESOURCE to ciudad or juntas." >&2
      return 1
      ;;
  esac

  "${bash_bin}" scripts/phase0_context_smoke.sh || return 1

  source runtime/env/latest/phase0_env.sh
  export ASSET_CONFIG
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
    and .type == "FeatureCollection"
    and (.features | type == "array")
    and all(
      .features[];
      type == "object"
      and .type == "Feature"
      and (.properties | type == "object")
      and (.geometry == null or (.geometry | type == "object"))
    )
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

export WFS_RESOURCE="<ciudad-or-juntas>"
run_wfs_flow
unset -f run_wfs_flow
```

Every phase sources the preceding phase environment before continuing. The resource selection explicitly sets `ASSET_CONFIG` before phase 1.

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

HTTP success and generic JSON syntax are not sufficient. The expected response is a GeoJSON object with:

- top-level `type` equal to `FeatureCollection`;
- a `features` array;
- feature objects with `type=Feature`;
- object-valued `properties`;
- object-valued or null `geometry`.

The executable block applies these semantic checks with `jq`.

Also verify:

- phase 4 is `ok` in `summary.json`;
- the manifest `suffix` and `asset_id` match the current execution;
- the manifest records a positive byte count and populated SHA-256;
- the selected layer is the one required by the integration.

The common scripts guarantee non-empty syntactically valid JSON for this asset metadata. The guide's post-download check adds the expected GeoJSON structure.

See [Evidence and traceability](../evidence-and-traceability.md) for manifest and publication rules.

## Flow-specific errors

### Endpoint unavailable

Symptoms include connection failure, non-2xx response, an empty response, or phase 4 exhausting its internal EDR authorization attempts.

Confirm that the upstream WFS profile in the selected asset configuration is reachable from the provider/Data Plane environment. Do not replace the public guide with a concrete host.

### Invalid response

If `jq` rejects the file, the upstream may have returned an HTML/XML error document or a truncated response. HTTP 200 does not override a failed content check.

Review the response headers, redacted attempt summary, and WFS service status. Do not accept the file as GeoJSON.

### Unexpected JSON format

Valid JSON that is not a GeoJSON `FeatureCollection` fails the semantic validation. Check:

- the selected WFS layer;
- the `GetFeature` request;
- the configured JSON output format;
- whether the service returned an application-level error object.

### Wrong content configuration

The current real WFS assets require `content_kind=json` and `extension=json`. A GML response must use a separately validated text/GML configuration and validation contract; renaming it to `.json` is not valid.

### Existing local output

If the run-specific target already exists with different content, phase 4 fails unless the operator deliberately uses the common `DOWNLOAD_FORCE=1` recovery control after verifying the run and destination.

## Legacy and non-current material

- `asset_configs/examples/emisiones_wfs.example.json` is a generic template, not a current validated IPPCP layer.
- `asset_configs/examples/emisiones_wfs_gml.example.json` is an unvalidated GML template for a different content contract.
- `v1` is legacy-supported and not used by the current block.
- `test3`, flat pre-versioned flow paths, and old workshop procedures are historical.

## Related documentation

- [Architecture](../architecture.md)
- [Authentication](../authentication.md)
- [Execution phases](../execution-phases.md)
- [Evidence and traceability](../evidence-and-traceability.md)
