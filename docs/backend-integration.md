# Backend Integration

## Purpose

This document defines how future backend components can reproduce the current IPPCP execution without exchanging `phase*_env.sh` files.

It is a conceptual integration contract, not an implemented backend API. Endpoint payloads, database technology, callbacks, queues, retry policy, and deployment topology still require design and validation.

The current executable reference remains the Bash sequence documented in [Execution phases](execution-phases.md).

## Integration principles

A backend implementation must:

1. preserve the `phase0` to `phase4` operation order;
2. persist durable execution state in a database;
3. correlate every operation with one `run_id`;
4. keep provider and consumer credentials in their owning backend;
5. retrieve short-lived JWTs and EDR authorization at runtime;
6. keep provider-side upstream secrets invisible to the consumer;
7. preserve evidence references, phase status, and terminal errors;
8. compose Management API URLs from environment-specific connector configuration and the operation source used by the current implementation.

Backends exchange state and identifiers. They do not exchange shell files, passwords, old JWTs, API keys, or EDR credentials.

## Component boundaries

### Provider backend

The planned provider backend would:

- authenticate `user_provider` against EdD Keycloak;
- create and manage provider-side vocabularies and policies when applicable;
- publish the asset and data address;
- publish the contract definition;
- verify provider-side catalog visibility;
- persist provider publication identifiers and evidence references;
- resolve upstream credentials from a provider-owned secret store.

For the Ingestion API, the provider backend supplies `X-Api-Key` and `X-Provider-Id` to asset publication. It never sends the API key to the consumer backend.

### Consumer backend

The planned consumer backend would:

- authenticate `user_consumer` against EdD Keycloak;
- request the remote provider catalog;
- select the asset and offer;
- create and monitor contract negotiation;
- retrieve the agreement;
- create and monitor the transfer process;
- retrieve and use the EDR at runtime;
- persist consumer execution identifiers, status, and evidence references.

The consumer backend must be able to complete phase 4 without access to the Ingestion API key. The Data Plane uses the provider-side data address to perform upstream authentication.

### Data Plane

The Data Plane:

- validates EDR authorization from the consumer side;
- resolves the provider asset data address;
- applies provider-side upstream headers;
- calls the upstream Ingestion API, WFS, or SPARQL resource with the HTTP method configured on the data address (`GET` by default; `POST` when `method=POST` and `proxyBody=true`);
- returns the data response to the authorized consumer.

For Ingestion API PROD POST assets, the consumer backend supplies the request body and `Content-Type` on the EDR hop. That body is not an upstream secret, but it may contain business data and must not be persisted in shared evidence the same way API keys must not. Transfer type remains `HttpData-PULL`.

The Data Plane separates consumer authorization from upstream authentication. The EDR credential and Ingestion API key must never be collapsed into one shared credential.

## Conceptual execution record

Each execution needs one durable record. The following shape describes required concepts; it is not a final API or database schema:

```json
{
  "run_id": "<stable-execution-id>",
  "dataspace": "<dataspace-key>",
  "flow": "<ingesta-or-consumo>",
  "flowVersion": "v2",
  "status": "<execution-status>",
  "currentPhase": "<phase0-through-phase4>",
  "assetId": null,
  "contractDefinitionId": null,
  "negotiationId": null,
  "agreementId": null,
  "transferProcessId": null,
  "providerManagement": {
    "accessPolicyId": null,
    "contractPolicyId": null,
    "vocabularyId": null
  },
  "asset": {
    "configurationRef": "<non-secret-config-reference>",
    "contentKind": null,
    "extension": null,
    "mediaType": null
  },
  "phaseStatus": {},
  "artifactRefs": [],
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>",
  "lastError": null
}
```

Connector profiles should be referenced by environment-specific configuration keys. Public records and documentation must not require concrete PRE or POST hosts.

## Core execution identifiers

Core identifiers represent the publication-negotiation-transfer chain:

| Backend concept | Current shell variable | Continuation and traceability role |
| --- | --- | --- |
| `assetId` | `ASSET_ID` | Required to select the catalog asset and correlate all later operations |
| `contractDefinitionId` | `CD_ID` | Proves which provider contract definition exposed the asset; supports provider management and cleanup |
| `negotiationId` | `NEG_ID` | Required to poll or resume negotiation before agreement resolution |
| `agreementId` | `AGREEMENT_ID` | Required to create the transfer and correlate the negotiated contract |
| `transferProcessId` | `TRANSFER_ID` | Required to poll transfer state and retrieve the EDR |

All five are part of the durable execution chain even when a completed phase means only a subset is needed for the next immediate call.

The external names remain distinct from current shell names. A future backend must not expose `CD_ID`, `NEG_ID`, or `TRANSFER_ID` merely because the scripts use those names.

## Optional provider-side management identifiers

The provider side can also persist:

| Backend concept | Current shell variable | Purpose |
| --- | --- | --- |
| `accessPolicyId` | `ACCESS_POLICY_ID` | Administration and correlation of the asset access policy |
| `contractPolicyId` | `CONTRACT_POLICY_ID` | Administration and correlation of the contract policy |
| `vocabularyId` | `VOCAB_ID` | Vocabulary administration when the publication uses one |

These identifiers support administration, audit, and possible future cleanup. They are not required by the consumer to negotiate or consume an already published asset, and they should not be mandatory fields in consumer-facing integration payloads.

`vocabularyId` is optional because not every publication requires a dedicated vocabulary operation.

## Replacing phase environment files

The current shell hand-off works as follows:

```text
phase0_env.sh -> phase1_env.sh -> phase2_env.sh -> phase3_env.sh
```

A future backend replaces this with transactional updates to the execution record:

### After phase 0 equivalent

Persist:

- `run_id`;
- dataspace, flow, and `flowVersion`;
- provider and consumer connector profile references;
- successful context/authentication status;
- phase 0 artifact references.

Do not persist connector passwords or EdD JWTs.

### After phase 1 equivalent

Persist:

- `assetId`;
- `contractDefinitionId`;
- applicable provider management identifiers;
- non-secret asset metadata;
- publication status and artifact references.

Do not persist the Ingestion API key in the execution record. Store it in a provider-owned secret store and use it only while constructing the provider publication request. The provider connector's data address retains the operational copy required by the Data Plane.

### After phase 2 equivalent

Persist:

- catalog selection metadata;
- `negotiationId`;
- negotiation state;
- `agreementId`;
- phase 2 artifact references.

### After phase 3 equivalent

Persist:

- `transferProcessId`;
- transfer state;
- confirmation that a resolvable EDR was observed;
- redacted EDR metadata and artifact references.

Do not persist EDR authorization. An EDR endpoint may also contain sensitive query parameters and must be omitted or redacted when necessary.

### After phase 4 equivalent

Persist:

- final data HTTP status;
- materialized object reference;
- byte count;
- media type;
- SHA-256;
- manifest reference;
- terminal execution status.

There is no `phase4_env.sh` equivalent because phase 4 is terminal for the current execution.

## State and status

The minimum requested execution fields are:

- `run_id`;
- `assetId`;
- `contractDefinitionId`;
- `negotiationId`;
- `agreementId`;
- `transferProcessId`;
- `status`.

Identifiers are nullable until their creating operation succeeds. A backend should update the identifier and the corresponding phase step atomically.

The exact status vocabulary is not finalized. It must at least distinguish:

- not started;
- in progress;
- succeeded;
- failed;
- skipped where the current scripts explicitly skip a compatibility operation.

Phase and step status should be retained separately from the overall execution status so a failed operation can be resumed without losing the completed chain.

## Credential management

Credential definitions and placeholders are owned by [Authentication](authentication.md). A backend implementation must preserve these ownership rules:

- the provider backend retrieves provider EdD credentials from its own secret manager;
- the consumer backend retrieves consumer EdD credentials from its own secret manager;
- each backend requests a fresh short-lived EdD JWT for its connector operations;
- the provider backend resolves the Ingestion API key without exposing it to shared state;
- the consumer backend retrieves the EDR at runtime and keeps its authorization in memory only;
- neither backend accepts old JWTs, EDR credentials, or shell credential files as cross-system integration payloads.

The Ingestion API key must remain transparent in the sense that it is invisible to the consumer backend. The consumer receives only the contract, transfer, EDR, and authorized data response.

Credential provisioning, rotation, revocation, onboarding, and offboarding are planned operational concerns. This repository does not demonstrate that they are automated.

## Operation sequence and path ownership

The future backend must reproduce the current connector operation sequence, but no final backend API is defined here.

Connector base URLs come from environment and dataspace configuration. Effective Management API URLs are composed as:

```text
connector base URL + operation path
```

[`endpoints.sh`](../endpoints.sh) is authoritative only for the request/list operation paths it declares:

- asset;
- policy definition;
- contract definition;
- contract agreement;
- transfer process;
- vocabulary.

The current implementation source for operations outside that file is:

| Operation | Current source |
| --- | --- |
| Asset, policy, vocabulary, and contract-definition create/item operations | [`scripts/phase1_provider_publish.sh`](../scripts/phase1_provider_publish.sh) |
| Provider self-catalog | [`scripts/phase1_provider_publish.sh`](../scripts/phase1_provider_publish.sh) |
| Consumer remote catalog | [`scripts/phase2_consumer_negotiate.sh`](../scripts/phase2_consumer_negotiate.sh) |
| Contract-negotiation create and state retrieval | [`scripts/phase2_consumer_negotiate.sh`](../scripts/phase2_consumer_negotiate.sh) |
| Contract-agreement item retrieval | [`scripts/phase2_consumer_negotiate.sh`](../scripts/phase2_consumer_negotiate.sh) |
| Transfer creation and state retrieval | [`scripts/phase3_transfer_edr.sh`](../scripts/phase3_transfer_edr.sh) |
| EDR retrieval and fallback request | [`scripts/phase3_transfer_edr.sh`](../scripts/phase3_transfer_edr.sh) and [`scripts/phase4_save_download.sh`](../scripts/phase4_save_download.sh) |

This incomplete centralization is a technical follow-up. Backend design must resolve the path source explicitly; it must not treat documentation copies as independent constants.

## Evidence and audit

The backend execution record should reference, rather than embed:

- request and response evidence;
- HTTP status metadata;
- redacted connector diagnostics;
- materialized downloads;
- manifests;
- package-export decisions.

The `run_id` must be present in logs, evidence metadata, and asynchronous work items without exposing credentials. Artifact storage must enforce the internal and publishable tiers defined in [Evidence and traceability](evidence-and-traceability.md).

## Concurrency, retries, and cleanup

The current scripts provide explicit force and resume controls, but they do not define a complete distributed-backend policy.

A backend design still needs decisions for:

- idempotency keys and duplicate-operation detection;
- optimistic locking or equivalent concurrent update protection;
- polling ownership and timeouts;
- retryable versus terminal connector errors;
- cancellation;
- partial publication cleanup;
- retention and deletion;
- callbacks or event delivery.

These capabilities are planned. They must not be represented as currently implemented or validated.

## Related documentation

- [Architecture](architecture.md)
- [Authentication](authentication.md)
- [Execution phases](execution-phases.md)
- [Evidence and traceability](evidence-and-traceability.md)
