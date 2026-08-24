# End-User Journey

## Purpose

This document describes the functional IPPCP journeys represented by the current architecture and validated technical implementation. It separates what a business user intends to achieve from what the current connector automation performs.

The journey model is:

```text
Access -> Understand -> Decide -> Act -> Result
```

## How to read the journeys

Each stage identifies:

- the actor and user goal;
- the visible system interaction;
- the corresponding data-space role;
- the expected visible result;
- the current implementation status;
- the canonical source supporting that status.

Status describes the complete journey stage, not only one underlying technical operation. A connector operation may be validated while its final end-user interface remains planned.

## Identity and security boundaries

The architecture contains two separate identity scopes:

- **Municipal application Keycloak:** used by the City Council platform and external application users. The current diagram shows it hosted temporarily in UPM infrastructure.
- **EdD Keycloak:** authenticates the provider and consumer technical users to their connector Management APIs.

Application authentication does not grant connector access. Connector technical credentials are not end-user application credentials.

The protected Ingestion API also has a separate upstream boundary. Its API key remains in the provider-side data address and is used by the Data Plane. It is invisible to the consumer and must not appear in user-facing state or evidence.

## Business stages and technical phases

The high-level architecture uses business stages:

- `PHASE A`: Intake;
- `PHASE B`: Consume;
- `PHASE C`: Consume by public companies.

These stages are distinct from the implemented script pipeline:

```text
phase0 -> phase1 -> phase2 -> phase3 -> phase4
```

Business stages explain user intent. The script phases implement connector context and authentication, provider publication, consumer negotiation, transfer and EDR retrieval, then authorized Data Plane consumption and technical result verification (materialized download or POST metadata-only). See [Architecture](../architecture.md) and [Execution phases](../execution-phases.md).

## External company or data provider

This journey describes the intended company-facing intake context in business Phase A. The current repository validates the Ingestion API v2 connector exchange, not a complete company-facing application workflow.

| Stage | Actor | User goal | System interaction | Data-space role | Visible result | Implementation status | Evidence or validation source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Access | External company user | Enter the municipal service through an authorized account | Authenticate through the municipal application Keycloak | No connector role is exposed to the end user | Authorized access to the intended municipal application | Planned | [Architecture diagram scope](../architecture.md#diagram-scope-and-terminology) |
| Understand | External company user or data provider | Understand what data is required and how it will be used | Review the intended intake requirements in the municipal platform | The future provider-side application prepares data for controlled publication | Requirements and expected submission outcome are clear | Planned | [Project and use-case rationale](project-justification.md#phase-a-intake) |
| Decide | External company user or data provider | Decide to submit or expose the requested data | Confirm the intended submission in the municipal application | Business consent precedes technical publication; it is not an EdD connector credential | A submission decision is recorded by the future application | Planned | [Backend integration](../backend-integration.md) |
| Act | External company user, provider-side application, and operator | Submit or expose data for controlled availability | The intended application hands the resource to the provider integration; the operator publishes the Ingestion API asset through `phase1` | `CONN-CITYCOUNCIL` is the current provider connector | The provider offer is available for controlled discovery and negotiation | Partially validated | [Ingestion API flow](../flows/ingestion-api.md) and [Execution phases](../execution-phases.md#phase-1-publication) |
| Result | External company or data provider | Know that the resource is available through a governed path | Review application confirmation when implemented; current validation uses sanitized phase and evidence status | The provider retains upstream credential ownership; the consumer receives no API key | Controlled technical availability is validated; final user-facing confirmation is planned | Partially validated | [Evidence and traceability](../evidence-and-traceability.md) |

### Provider responsibilities

The current provider-side technical path:

- authenticates the provider technical user through EdD Keycloak;
- publishes policies, the asset, data address, and contract definition;
- keeps any Ingestion API credential provider-side;
- supports correlation through `run_id`, currently represented by `SUFFIX`;
- exposes only the governed offer to the consumer.

## City Council or functional consumer

This journey describes the City Council as a **business consumer** in Phase B. That functional role must not be confused with the current technical connector assignment: `CONN-CITYCOUNCIL` is the provider connector and `CONN-COMPANY` is the consumer connector for current v2 flows.

| Stage | Actor | User goal | System interaction | Data-space role | Visible result | Implementation status | Evidence or validation source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Access | City Council user and technical operator | Reach the municipal processing context and a ready data-space environment | The user enters the intended application through municipal Keycloak; the operator separately authenticates connector technical users through EdD Keycloak | Business-user access and connector authentication remain separate | Application access is intended; connector readiness is validated | Partially validated | [Authentication](../authentication.md) and [Getting Started](../getting-started.md) |
| Understand | City Council stakeholder | Identify which available resource supports the municipal task | Review the intended resource context; the current technical path queries the provider catalog | `CONN-COMPANY` performs the current consumer-side catalog request | The required WFS, SPARQL, or Ingestion API offer can be identified technically | Partially validated | [Architecture control flow](../architecture.md#control-flow) |
| Decide | City Council stakeholder and consumer-side operator | Decide whether to request access under the offered conditions | Review the intended offer and start contract negotiation through the current scripts | The consumer connector negotiates and obtains the agreement | A valid agreement authorizes the next technical step | Partially validated | [Execution phases](../execution-phases.md#phase-2-negotiation) |
| Act | Consumer-side operator on behalf of the functional use case | Retrieve and use the selected resource | Start transfer, retrieve an EDR, and execute phase4 through the Data Plane | The consumer connector obtains the EDR; the Data Plane resolves the provider data address | A verified technical result: materialized download (WFS/SPARQL/PRE GET) or POST metadata-only (PROD POST) | Validated | [WFS](../flows/wfs.md), [SPARQL](../flows/sparql.md), and [Ingestion API](../flows/ingestion-api.md) |
| Result | City Council stakeholder and operator | Retain an understandable result and traceability | Review sanitized summary; materialized flows add manifest and SHA-256; PROD POST adds safe POST control metadata | The execution correlates publication, agreement, transfer, and phase4 result under one run | Verified technical result with run-level evidence | Validated | [Evidence and traceability](../evidence-and-traceability.md) |

### Consumer responsibilities

The current consumer-side technical path:

- authenticates the consumer technical user through EdD Keycloak;
- discovers the offer and negotiates an agreement;
- starts transfer and retrieves the EDR;
- uses EDR authorization only at runtime;
- downloads through the Data Plane where the profile materializes a response;
- validates materialized representations where applicable;
- never receives the provider's Ingestion API key.

## Public-company consumer

Business Phase C represents an intended downstream journey for public-company consumption. The diagram provides the business and infrastructure context, but the repository does not validate a distinct Phase C application or technical workflow.

| Stage | Actor | User goal | System interaction | Data-space role | Visible result | Implementation status | Evidence or validation source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Access | Public-company user | Enter an authorized service context | Authenticate through the intended application boundary | A final connector assignment for the complete Phase C journey is not implemented here | Authorized application entry | Planned | [Architecture](../architecture.md) |
| Understand | Public-company user | Identify available data relevant to its task | Review the future application presentation of available resources and conditions | Future integration would map the user request to data-space discovery | Understandable resource and conditions | Planned | [Project and use-case rationale](project-justification.md#phase-c-consume-by-public-companies) |
| Decide | Public-company user | Decide whether to request or use the resource | Confirm the intended request through a future application workflow | Future backend behavior must preserve negotiation and credential boundaries | Recorded access decision | Planned | [Backend integration](../backend-integration.md) |
| Act | Public-company user and future consumer backend | Obtain the authorized resource | Future backend would execute the required connector sequence and retrieve authorization at runtime | Consumer-side state and credentials remain in the owning backend | Authorized resource retrieval | Planned | [Backend integration](../backend-integration.md#credential-management) |
| Result | Public-company stakeholder | Use the result while retaining traceability | Future application presents the result and references sanitized execution evidence | `run_id` and connector identifiers correlate the technical execution | Business result with governed traceability | Planned | [Evidence and traceability](../evidence-and-traceability.md) |

Phase C must not be demonstrated as technically validated unless a distinct implementation and evidence set are completed and approved.

## Journey result and traceability

Across validated technical variants, the terminal result consists of:

- a completed phase status sequence;
- provider asset and contract-definition identifiers;
- consumer negotiation and agreement identifiers;
- transfer-process correlation;
- a verified phase 4 technical result:
  - **materialized response:** non-empty download, flow-specific semantic validation, manifest with byte count and SHA-256;
  - **POST metadata-only:** HTTP 2xx control metadata (`post_result.json` / `post_manifest.json`), no persisted request/response bodies;
- evidence organized under one `run_id`/`SUFFIX`.

Raw passwords, JWTs, API keys, EDR authorization, local paths, and business-sensitive payloads are not valid public journey evidence.

## Related documentation

- [Project and use-case rationale](project-justification.md)
- [Final demo guide](final-demo.md)
- [Readiness checklist](readiness-checklist.md)
- [Architecture](../architecture.md)
- [Authentication](../authentication.md)
- [Execution phases](../execution-phases.md)
- [Backend integration](../backend-integration.md)
- [Evidence and traceability](../evidence-and-traceability.md)
