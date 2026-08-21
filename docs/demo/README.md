# Demo Documentation

## Purpose

This package supports public-safe explanation, preparation, and demonstration of the current IPPCP data exchanges. It connects the functional use case to validated technical behavior without replacing the canonical architecture, authentication, execution, or evidence documents.

## Demo package

- [Project and Use-Case Rationale](project-justification.md): context, stakeholder value, business stages, capabilities, evidence roles, and limitations.
- [Final Demo Guide](final-demo.md): roles, selectable validated variants, live sequence, success criteria, evidence rules, and contingencies.
- [End-User Journey](end-user-journey.md): Access → Understand → Decide → Act → Result for provider, City Council, and public-company journeys.
- [Demo Readiness Checklist](readiness-checklist.md): functional, environment, flow, evidence, presentation, contingency, publication, and go/no-go checks.

## Canonical references

- [Workshop](../workshop.md)
- [Architecture](../architecture.md)
- [Getting Started](../getting-started.md)
- [Authentication](../authentication.md)
- [Execution phases](../execution-phases.md)
- [Evidence and traceability](../evidence-and-traceability.md)

## Flow guides

- [Ingestion API](../flows/ingestion-api.md)
- [WFS](../flows/wfs.md)
- [SPARQL](../flows/sparql.md)

## Status vocabulary

- **Validated:** demonstrated end-to-end with a materialized phase4 result and verified manifest.
- **Partially validated:** one or more technical parts are validated, while the complete user-facing or integrated capability is not.
- **Planned:** intended future capability that is not presented as implemented.
- **Legacy-supported:** retained project material that is not recommended for new integration.
- **Delivered baseline:** accepted delivery evidence retained with its original meaning.
- **Out of current scope:** not claimed by the current validated package.

Technical status and evidence role are separate. T1–T4 are presentation slots. CSV/B2 remains a preserved historical baseline; it is not the current workshop path.

## Public-safety boundary

Operational credentials, API keys, JWTs, EDR authorization, concrete internal hosts, raw evidence, local paths, and business-sensitive payloads are not stored in this package. Any screenshot, recording, prepared output, or evidence extract must be sanitized and approved before presentation or publication.
