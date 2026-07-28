# Diagrams

This directory is reserved for reviewed architecture and execution diagrams.

## Canonical architecture diagram

The IPPCP architecture diagram is the canonical high-level functional and infrastructure overview. It is not an exhaustive low-level EDC sequence diagram; the linked architecture document owns the detailed technical behavior and status classifications.

- `ippcp-architecture.drawio` is the editable source of truth.
- `ippcp-architecture.svg` is the primary rendering for Markdown, GitHub, and full-size viewing.
- `ippcp-architecture.png` is the compatibility and presentation export.

All three files represent the same diagram. When the diagram changes, update and review the Draw.io source, SVG rendering, and PNG export together.

## Maintenance rules

- edit only the Draw.io source, then export the SVG and PNG from that source;
- keep the three files synchronized and review them together;
- avoid internal endpoints, credentials, local paths, and raw evidence;
- use [Architecture](../architecture.md) as the canonical narrative and status reference;
- be reviewed before export to the public repository.
