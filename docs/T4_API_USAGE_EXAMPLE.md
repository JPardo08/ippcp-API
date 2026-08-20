# T4 Ingestion API usage example

The `T4` in this filename is historical. Current evidence tooling treats T1–T4 as slots; Ingestion API v2 is classified from the run and uses `minimal_publication` in any slot.

## Purpose

This sanitized companion explains the current IPPCP v2 Ingestion API integration. It covers a controlled direct preflight and access through the EdD data space. It contains no operational credentials, execution identifiers, local paths, response payloads, or private hashes.

## Direct upstream preflight

The upstream operation is an HTTP `GET` request to the intake path. It has no request body and no required query parameters.

```bash
: "${INGESTA_API_BASE_URL:?Set the approved upstream base URL}"
: "${INGESTA_API_KEY:?Load the provider-side API key securely}"
: "${INGESTA_API_PROVIDER_ID:?Load the provider-side identifier securely}"

output_file="data/real/ingesta/responses/pre/ingestion-response.json"
mkdir -p "$(dirname "${output_file}")"

curl --fail-with-body --silent --show-error --get \
  "${INGESTA_API_BASE_URL%/}/api/intake" \
  --header "Accept: application/json" \
  --header "X-Api-Key: ${INGESTA_API_KEY}" \
  --header "X-Provider-Id: ${INGESTA_API_PROVIDER_ID}" \
  --output "${output_file}"
```

`X-Api-Key` and `X-Provider-Id` are header names. Their values remain provider-side operational data and are never published.

Inspect only the response shape, without printing records:

```bash
jq '{
  response_type: type,
  record_count: (if type == "array" then length else null end)
}' "${output_file}"
```

The response file remains local, non-versioned output under a path covered by `.gitignore`; it must not enter Git or public evidence.

## T4 through the EdD data space

1. The city-council connector acts as provider and publishes the protected API as an `HttpData-PULL` asset.
2. Upstream header values are retained in the provider-side data address.
3. The company connector acts as consumer and discovers the offer in the federated catalog.
4. The consumer negotiates the contract and starts the transfer.
5. The EdD exposes the runtime endpoint information required for authorized Data Plane access.
6. The provider Data Plane applies the upstream headers and invokes the Ingestion API.
7. The consumer receives the result through the data-space path without receiving the upstream API credentials.

The current public workflow version is v2. Legacy v1/B2 material exists only for historical reproducibility and is not the current Ingestion API path.

## Authentication boundaries

EdD Management APIs use the connector OAuth service and provisioned technical users. The protected upstream API uses provider-side `X-Api-Key` and `X-Provider-Id` values. Runtime Data Plane access material is a third boundary and is omitted from this document and from public evidence.

These credentials are not interchangeable. Upstream credential values remain provider-side and are excluded from public documentation, evidence artifacts, and consumer-facing examples.

## Evidence and publication status

Sanitized Ingestion API evidence artifacts use the `minimal_publication` profile attached to `ingestion_api_v2`, not to slot T4. They are delivered separately from this repository and are not claimed to be hosted or versioned in Git.

This Markdown file is companion documentation, not an evidence artifact.

Versioned synthetic examples live in `examples/evidence/t4-ingestion-api/`. The directory name is historical. The synthetic public example may show `semantic_validation.status = passed`; that status applies only to the synthetic example.

Externally delivered Ingestion API evidence deliberately uses `semantic_validation.status = not_recorded` under the `minimal_publication` profile. This means semantic details were intentionally not recorded in the public projection and does not indicate a functional failure of the validated flow. The synthetic-example status and the real-delivery status are not asserted to be identical.

Exporter commands: [`tools/tools_README.md`](../tools/tools_README.md). Publication rules: [Evidence Publication Policy](evidence-publication.md).

## Security notice

The public companion and separate evidence artifacts exclude credential values, runtime access material, execution and connector object identifiers, local filesystem paths, raw requests and responses, downloaded payloads, provider data-address content, and private payload hashes.

Operational values must be provisioned through an approved secret-management channel and must never be inserted into this document or committed to source control.
