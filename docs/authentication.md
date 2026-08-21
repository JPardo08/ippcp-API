# Authentication

This is a reference document. Local credential setup for a clean clone is in [workshop.md](workshop.md).

## Purpose

This document is the canonical source for authentication and secret-handling rules in the current IPPCP flows.

IPPCP has three independent authentication boundaries:

1. EdD Keycloak authenticates technical users to connector Management APIs.
2. The EDR credential authorizes consumer access to the Data Plane.
3. Upstream credentials authorize the Data Plane to access a protected provider resource.

A credential issued for one boundary must not be reused or exposed at another boundary.

## Credential ownership

| Credential | Owner | Used on | Persistence rule |
| --- | --- | --- | --- |
| Provider username and password | Provider-side operator or future provider backend | Provider technical user to EdD Keycloak | Local secret store only |
| Consumer username and password | Consumer-side operator or future consumer backend | Consumer technical user to EdD Keycloak | Local secret store only |
| Provider EdD JWT | Provider-side runtime | Provider connector Management API | Runtime only; never evidence or shared state |
| Consumer EdD JWT | Consumer-side runtime | Consumer connector Management API | Runtime only; never evidence or shared state |
| EDR credential | Consumer-side runtime | Consumer to Data Plane | Retrieve at runtime; never public evidence |
| Ingestion API key | Provider side and provider connector data address | Data Plane to Ingestion API | Provider-side secret; never disclosed to consumer |
| Ingestion provider identifier | Provider side | Data Plane to Ingestion API | Configuration value; treat as non-public operational data |

## EdD connector authentication

### Technical users

The current scripts use two independent technical-user roles:

- `user_provider` authenticates operations against the provider connector.
- `user_consumer` authenticates operations against the consumer connector.

The roles may currently resolve to credentials provisioned for the same person in an assessment environment. They remain separate roles and future backends must manage them independently.

Local credential files are:

```text
flujos/ippcp/v2/<flow>/user_provider.sh
flujos/ippcp/v2/<flow>/user_consumer.sh
```

The files are ignored and must not be committed. The repository contains `.example.sh` templates for their structure.

### Placeholder definitions

Use placeholders in documentation and examples:

```bash
export PROVIDER_USERNAME="<provider-technical-user>"
export PROVIDER_PASSWORD="<provider-password>"
export CONSUMER_USERNAME="<consumer-technical-user>"
export CONSUMER_PASSWORD="<consumer-password>"
```

The compatibility layer maps `PROVIDER_USERNAME` and `CONSUMER_USERNAME` to the internal `PROVIDER_USER` and `CONSUMER_USER` names used by the scripts.

The selected dataspace configuration supplies:

```bash
export KEYCLOAK_URL="<edd-keycloak-base-url>"
export DS_NAME="<edd-realm>"
export KC_CLIENT="<edd-client-id>"
```

Do not copy environment-specific hosts from assessment files into public documentation.

### Token acquisition and use

The scripts use the OAuth 2.0 resource-owner password flow exposed by the current EdD deployment to obtain short-lived JWTs for the provider and consumer technical users. The JWTs are sent as Bearer credentials only to their respective connector Management APIs.

The current behavior is implemented in [`scripts/lib_common.sh`](../scripts/lib_common.sh). Phase scripts refresh JWTs when required.

Connector JWTs:

- are not upstream Ingestion API credentials;
- are not EDR credentials;
- must not be passed between provider and consumer systems;
- must not be written to `phase*_env.sh`, `summary.json`, logs, manifests, or evidence;
- must not be committed or included in support bundles.

## Ingestion API authentication

### Current `v2` model

The current Ingestion API uses these headers on the Data Plane-to-upstream hop:

- `X-Api-Key`;
- `X-Provider-Id`.

Phase 1 receives them through:

```bash
export INGESTA_API_KEY="<ingestion-api-key>"
export INGESTA_API_PROVIDER_ID="<numeric-provider-id>"
```

The provider identifier is the numeric application identifier expected by the Ingestion API. It is not a Keycloak UUID.

The local ignored file is created from:

```text
data/real/ingesta/auth/ingesta_api_key.env.example
```

The canonical asset configuration declares that both headers are required. During phase 1, the script validates the variables and injects these data-address properties into the publication request:

```text
header:X-Api-Key
header:X-Provider-Id
```

The real publication payload is temporary. Persisted phase 1 evidence replaces the API-key value with `<redacted>`.

### Persistence and visibility

The API key is persisted in the provider connector's asset data address for the assessment so that the Data Plane can call the upstream API. It must be handled as a provider-side secret.

The API key:

- must not be stored by the consumer or a future consumer backend;
- must not be returned through the catalog, agreement, EDR, or data response;
- must not be copied to shared execution state;
- must not appear in evidence, logs, manifests, shell history, or documentation;
- must be redacted before any artifact is persisted.

The current asset does not contain an upstream JWT. The previous upstream Bearer-token flow is historical and must not be used for a clean v2 Ingestion API execution.

## EDR authorization

An Endpoint Data Reference contains the Data Plane endpoint and its authorization material. The consumer connector exposes the EDR only after a transfer has been initiated.

The current scripts retrieve an EDR at runtime using the consumer EdD JWT. They then use the EDR credential to call the Data Plane.

Observed valid current behavior uses the value returned in the EDR `authorization` field as the `Authorization` header value without adding a scheme. The implementation labels this candidate `authorization_raw`. Other forms attempted internally by the scripts are compatibility fallbacks; they are not user configuration steps.

EDR material:

- belongs to the consumer-side runtime;
- can expire or be replaced;
- must be retrieved again when phase 4 runs;
- must not be used to authenticate to Keycloak or directly to the Ingestion API;
- must not be written unredacted to evidence or public logs.

Phase 3 may persist a non-sensitive EDR URL for hand-off. If the URL contains sensitive query parameters, the script omits it from persisted phase state. Authorization material is never exported through `phase3_env.sh`.

## Secret loading and phase hand-off

Credential files are sourced locally for each execution. They are not phase outputs.

`phase*_env.sh` files contain execution identifiers, selected configuration, and non-secret hand-off state. They intentionally exclude:

- provider and consumer passwords;
- provider and consumer JWTs;
- the Ingestion API key;
- EDR authorization values.

Phase 4 re-authenticates the consumer and retrieves the EDR at runtime instead of relying on a persisted EDR credential. Phase 4 does not create `phase4_env.sh`.

Future backends must follow the same boundary: exchange durable execution state, not shell credential files, old JWTs, or EDR credentials.

## Secret boundaries

Never commit, publish, or transfer:

- provider or consumer passwords;
- full connector JWTs;
- `INGESTA_API_KEY`;
- EDR authorization values;
- OAuth client secrets;
- storage credentials;
- local `user_provider.sh`, `user_consumer.sh`, or `.env` files.

Never place secret values directly in command lines shown in documentation. Source an ignored local file or use a secret manager.

Each future backend is responsible for resolving its own credentials locally:

- the provider backend manages provider EdD credentials and provider-side upstream secrets;
- the consumer backend manages consumer EdD credentials and runtime EDR use;
- the Data Plane resolves the provider asset data address without disclosing its upstream secret to the consumer.

Credential provisioning, rotation, revocation, onboarding, and offboarding are not implemented or validated by these scripts. They remain operational and backend-design responsibilities.

## Evidence rules

Persisted evidence may include:

- credential field names;
- HTTP status codes;
- redacted data-address structures;
- non-sensitive provider identifiers when publication policy permits.

Persisted evidence must not include:

- passwords or client secrets;
- Bearer tokens or JWT payloads;
- API-key values;
- EDR authorization values;
- sensitive URL query parameters.

See [Evidence and traceability](evidence-and-traceability.md) for publication tiers and redaction requirements.

## Related documentation

- [Architecture](architecture.md)
- [Execution phases](execution-phases.md)
- [Evidence and traceability](evidence-and-traceability.md)
- [Backend integration](backend-integration.md)
