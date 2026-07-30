# IPPCP API

## Overview

This repository contains command-line automation and technical documentation for validating IPPCP data exchanges through an INESData data space.

The current workflow publishes a provider asset, discovers it from a consumer connector, negotiates access, starts a transfer, retrieves an Endpoint Data Reference (EDR), and materializes an authorized local download.

The implementation is currently operated through Bash phase scripts. A final backend API is not presented as implemented.

## Public access and execution boundary

This repository is public. Its documentation and automation may be reviewed and reused under the terms of the [Apache License 2.0](LICENSE).

Running the validated flows requires network access to the configured connectors, provisioned technical users, local credentials, and valid configuration for both the environment and the selected upstream resource. These operational elements are not supplied by the public repository. Without them, the repository remains a technical and automation reference, not a standalone EdD environment, and access to the validated PRE profile must not be assumed.

## Architecture

[![IPPCP logical architecture across city council and UPM infrastructures, provider and consumer connectors, and upstream data resources](docs/diagrams/ippcp-architecture.svg)](docs/diagrams/ippcp-architecture.svg)

[Architecture](docs/architecture.md) is the current source for actors, control and data planes, security boundaries, and implementation status.

## Supported flows

The current public flows use `HttpData-PULL`:

- [Ingestion API](docs/flows/ingestion-api.md): a protected JSON API whose upstream headers remain provider-side.
- [WFS](docs/flows/wfs.md): current city and district-board GeoJSON layers.
- [SPARQL](docs/flows/sparql.md): SPARQL Results JSON with an explicit response format.

Each flow guide defines its asset configuration, flow-specific variables, complete execution block, semantic content validation, and common errors.

## How the workflow works

The current sequence is:

```text
phase0 -> phase1 -> phase2 -> phase3 -> phase4
```

- Phase 0 resolves context, authenticates provider and consumer connector roles, and performs smoke checks.
- Phase 1 publishes provider policies, the asset, its data address, and the contract definition.
- Phase 2 discovers the asset, negotiates access, and obtains the agreement.
- Phase 3 starts the transfer and retrieves an EDR.
- Phase 4 retrieves a current EDR, downloads data through the Data Plane, and writes a manifest with SHA-256.

See [Execution phases](docs/execution-phases.md) for the canonical phase model and inherited state.

## Requirements

- Bash 4.3 or newer.
- Git.
- `curl` and `jq`.
- Python 3, recommended for diagnostics.
- Network access to the configured EdD connectors and selected upstream resource.
- Provider and consumer EdD technical credentials for the configured dataspace/connectors.
- Flow-specific upstream secrets only when required.

Passwords, tokens, API keys, and EDR authorization must remain outside Git and public documentation.

## Quick start

Clone the public repository and enter its root:

```bash
git clone https://github.com/JPardo08/ippcp-API.git
cd ippcp-API
```

Then follow [Getting Started](docs/getting-started.md) to:

1. select Bash and verify dependencies;
2. prepare ignored provider and consumer credential files;
3. select `IPPCP_DATASPACE`, `IPPCP_FLOW`, and `IPPCP_FLOW_VERSION=v2`;
4. choose the Ingestion API, WFS, or SPARQL guide;
5. run phase 0 through phase 4;
6. verify the run summary, download, manifest, and SHA-256.

Do not copy a complete flow from historical or internal material. Use the current flow guides linked below.

## Documentation

Start here:

- [Getting Started](docs/getting-started.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Demo documentation](docs/demo/README.md)

Canonical technical references:

- [Architecture](docs/architecture.md)
- [Authentication](docs/authentication.md)
- [Execution phases](docs/execution-phases.md)
- [Evidence and traceability](docs/evidence-and-traceability.md)
- [Backend integration](docs/backend-integration.md)

Flow guides:

- [Ingestion API](docs/flows/ingestion-api.md)
- [WFS](docs/flows/wfs.md)
- [SPARQL](docs/flows/sparql.md)

The public entry path intentionally does not promote internal migration notes, archived procedures, raw evidence, or obsolete workshop documentation.

## Current and legacy versions

`v2` is current and recommended for new integrations.

`v1` is retained as legacy-supported project material. It is not used by the recommended quick start.

`test3`, discarded experiments, upstream JWT authentication, flat pre-versioned paths, and old workshop procedures are historical or obsolete.

The B2/CSV/InesDataStore T1 delivery remains a preserved evidence baseline. It is distinct from the recommended current `HttpData-PULL` integration.

## Validation status

The current Ingestion API, WFS, and SPARQL flows have been validated end-to-end in the available PRE profile, including phase 4 download and manifest creation.

PRE is the currently validated environment profile, not a universal deployment requirement. Other environments require their own validated connector and upstream configuration.

Public documentation does not publish internal connector hosts, execution identifiers, UUIDs, hashes, credentials, or raw business data.

See [Evidence and traceability](docs/evidence-and-traceability.md) for the distinction between internal evidence and approved publishable artifacts.

## Security

Never commit or publish:

- provider or consumer passwords;
- connector tokens;
- Ingestion API keys;
- EDR authorization;
- OAuth client secrets;
- storage credentials;
- ignored local credential or environment files;
- sensitive URL parameters;
- raw business data.

Provider and consumer EdD credentials authenticate their configured connectors. Flow-specific upstream credentials protect a different network hop and must not be shared with the consumer.

Use run-specific summaries and redacted artifacts for diagnosis. Do not reproduce the internal EDR authorization candidate loop manually.

## License and acknowledgements

This repository is developed in the context of the IPPCP project and its INESData data-space integration.

The repository is licensed under the [Apache License 2.0](LICENSE), which defines the applicable permissions and conditions. Related project attribution is recorded separately in [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md); it does not modify the license.
