#!/usr/bin/env python3
"""Synthetic evidence-run fixtures for slot/asset tests. No real suffixes or business data."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, Iterable, Optional


ASSET_FIXTURES = {
    "ingestion_api_v2": {
        "suffix": "synthetic-ingestion-api",
        "slug": "ippcp_ingesta_api_pull_pre_api_key",
        "asset_config": "asset_configs/real/ingesta/ingesta_api_pull_pre_api_key.json",
        "kind": "b1",
        "content_kind": "json",
        "extension": "json",
        "media_type": "application/json",
        "transfer_type": "HttpData-PULL",
        "requires_api_key_header": True,
        "payload": {"status": "ok", "items": []},
        "payload_name": "downloaded.json",
    },
    "csv_b2_legacy": {
        "suffix": "synthetic-csv-b2",
        "slug": "ippcp_ingesta_bbdd_residencial_2021_csv",
        "asset_config": "asset_configs/real/ingesta/ingesta_bbdd_residencial_2021_csv.json",
        "kind": "b2",
        "content_kind": "text",
        "extension": "csv",
        "media_type": "text/csv",
        "transfer_type": "AmazonS3-PUSH",
        "payload": "id,name\n1,synthetic\n",
        "payload_name": "downloaded.csv",
    },
    "wfs_juntas": {
        "suffix": "synthetic-wfs-juntas",
        "slug": "ippcp_emisiones_wfs_juntas_geojson",
        "asset_config": "asset_configs/real/consumo/wfs/emisiones_wfs_juntas_geojson.json",
        "kind": "b1",
        "content_kind": "json",
        "extension": "json",
        "media_type": "application/json",
        "transfer_type": "HttpData-PULL",
        "payload": {"type": "FeatureCollection", "features": []},
        "payload_name": "downloaded.json",
    },
    "wfs_ciudad": {
        "suffix": "synthetic-wfs-ciudad",
        "slug": "ippcp_emisiones_wfs_ciudad_geojson",
        "asset_config": "asset_configs/real/consumo/wfs/emisiones_wfs_ciudad_geojson.json",
        "kind": "b1",
        "content_kind": "json",
        "extension": "json",
        "media_type": "application/json",
        "transfer_type": "HttpData-PULL",
        "payload": {
            "type": "FeatureCollection",
            "features": [{"type": "Feature", "properties": {"id": 1}, "geometry": None}],
        },
        "payload_name": "downloaded.json",
    },
    "sparql": {
        "suffix": "synthetic-sparql",
        "slug": "ippcp_emisiones_sparql_limit10_format_json",
        "asset_config": "asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json",
        "kind": "b1",
        "content_kind": "json",
        "extension": "json",
        "media_type": "application/sparql-results+json",
        "transfer_type": "HttpData-PULL",
        "payload": {"head": {"vars": ["s", "p", "o"]}, "results": {"bindings": []}},
        "payload_name": "downloaded.json",
    },
}


def write_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def _phases_for(kind: str, status: str = "ok") -> Dict[str, Any]:
    names = (
        ("phase0", "phase1b", "phase2", "phase3b", "phase4b")
        if kind == "b2"
        else ("phase0", "phase1", "phase2", "phase3", "phase4")
    )
    return {phase: {"status": status, "steps": []} for phase in names}


def create_asset_run(
    root: Path,
    asset_key: str,
    suffix: Optional[str] = None,
    *,
    incomplete: bool = False,
    with_canaries: bool = False,
) -> Path:
    spec = dict(ASSET_FIXTURES[asset_key])
    suffix = suffix or spec["suffix"]
    run = root / "evidencias" / "runs" / suffix
    kind = spec["kind"]
    phases = _phases_for(kind, "ok")
    if incomplete:
        if kind == "b2":
            phases.pop("phase4b", None)
        else:
            phases.pop("phase4", None)

    asset_id = f"{spec['slug']}-{suffix}"
    create_step = {
        "id": "create_asset" if kind == "b1" else "get_asset",
        "status": "ok",
        "asset_id": asset_id,
        "asset_slug": spec["slug"],
        "asset_config": spec["asset_config"],
        "content_kind": spec["content_kind"],
        "extension": spec["extension"],
        "media_type": spec["media_type"],
    }
    if spec.get("requires_api_key_header"):
        create_step["requires_api_key_header"] = True
    publish_phase = "phase1" if kind == "b1" else "phase1b"
    phases[publish_phase]["steps"] = [create_step]

    transfer_phase = "phase3" if kind == "b1" else "phase3b"
    if transfer_phase in phases:
        phases[transfer_phase]["steps"] = [
            {
                "id": "transfer_type_valid" if kind == "b1" else "transfer_started",
                "status": "ok",
                "transfer_type": spec["transfer_type"],
            },
            {
                "id": "transfer_final_state",
                "status": "ok",
                "final_state": "COMPLETED" if kind == "b1" else "STARTED",
                "transfer_type": spec["transfer_type"],
            },
        ]

    download_phase = "phase4" if kind == "b1" else "phase4b"
    download_step_id = "save_download" if kind == "b1" else "storage_fetch"
    if download_phase in phases:
        phases[download_phase]["steps"] = [
            {
                "id": download_step_id,
                "status": "ok",
                "bytes": 32,
                "sha256": "b" * 64,
                "content_kind": spec["content_kind"],
                "extension": spec["extension"],
                "media_type": spec["media_type"],
                "latest_file": f"{download_phase}/{spec['payload_name']}",
            }
        ]

    summary: Dict[str, Any] = {
        "suffix": suffix,
        "ds_name": "synthetic",
        "started_at": "2026-08-19T00:00:00Z",
        "phases": phases,
    }
    if with_canaries:
        summary["jwt"] = "eyJFAKECANARYTOKEN0123456789"
        summary["internal_url"] = "https://canary.internal.invalid/api"
        if download_phase in phases:
            phases[download_phase]["steps"][0]["authorization"] = "Bearer CANARY-AUTHORIZATION"

    write_json(run / "summary.json", summary)
    write_json(
        run / download_phase / "download_manifest.json",
        {
            "bytes": 32,
            "sha256": "b" * 64,
            "asset_id": asset_id,
            "asset_slug": spec["slug"],
            "content_kind": spec["content_kind"],
            "extension": spec["extension"],
            "media_type": spec["media_type"],
            "transfer_type": spec["transfer_type"],
        },
    )
    write_json(run / download_phase / "semantic_validation.json", {"status": "passed"})
    payload_path = run / download_phase / spec["payload_name"]
    payload_path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(spec["payload"], str):
        payload_path.write_text(spec["payload"], encoding="utf-8")
    else:
        write_json(payload_path, spec["payload"])
    if with_canaries:
        (run / "phase1_env.sh").write_text(
            "export INGESTA_API_KEY=CANARY-API-KEY\n"
            "export PASSWORD=CANARY-PASSWORD\n"
            "export PATH_VALUE=/Users/example/private\n",
            encoding="utf-8",
        )
        write_json(
            run / "phase1" / "13_create_asset.json",
            {
                "header:X-Api-Key": "CANARY-API-KEY",
                "dataAddress": "CANARY-DATA-ADDRESS",
                "authorization": "Bearer CANARY-AUTHORIZATION",
            },
        )
    for phase in phases:
        write_json(run / phase / "status.json", {"status": phases[phase]["status"]})
    return run


def create_unknown_run(root: Path, suffix: str = "synthetic-unknown") -> Path:
    run = root / "evidencias" / "runs" / suffix
    write_json(
        run / "summary.json",
        {
            "suffix": suffix,
            "phases": {
                "phase0": {"status": "ok", "steps": []},
                "phase1": {"status": "ok", "steps": []},
            },
        },
    )
    return run


def create_ambiguous_run(root: Path, suffix: str = "synthetic-ambiguous") -> Path:
    run = root / "evidencias" / "runs" / suffix
    write_json(
        run / "summary.json",
        {
            "suffix": suffix,
            "phases": {
                "phase0": {"status": "ok", "steps": []},
                "phase1": {
                    "status": "ok",
                    "steps": [
                        {
                            "id": "create_asset",
                            "status": "ok",
                            "asset_slug": "ippcp_emisiones_wfs_ciudad_geojson",
                            "asset_config": "asset_configs/real/consumo/wfs/emisiones_wfs_juntas_geojson.json",
                            "content_kind": "json",
                            "extension": "json",
                            "media_type": "application/json",
                        }
                    ],
                },
            },
        },
    )
    return run


def tests_override(mapping: Dict[str, str]) -> str:
    return ",".join(f"{slot}={suffix}" for slot, suffix in mapping.items())


def complete_override(order: Iterable[str]) -> str:
    return tests_override(
        {f"T{index}": ASSET_FIXTURES[key]["suffix"] for index, key in enumerate(order, 1)}
    )


def create_ingestion_post_metadata_run(
    root: Path,
    *,
    suffix: str = "synthetic-ingestion-post",
    slug: str = "ippcp_ingesta_pull_industrias_ebro_prod",
    asset_config: str = "asset_configs/real/ingesta/ingesta_api_pull_industrias_ebro_prod.json",
    http_status: int = 200,
    request_body_persisted: bool = False,
    response_body_persisted: bool = False,
    download_persisted: bool = False,
    status: str = "ok",
    manifest_kind: str = "post_metadata_only",
    include_post_result: bool = True,
    include_post_manifest: bool = True,
    with_canaries: bool = False,
) -> Path:
    """Synthetic ingestion_api_v2 POST metadata-only run (no download/sha256/payload)."""
    run = root / "evidencias" / "runs" / suffix
    # Stable synthetic ids — not copied from real PROD evidence.
    asset_id = "ippcp-ingesta-pull-industrias-ebro-prod"
    agreement_id = "00000000-0000-4000-8000-000000000001"
    transfer_id = "00000000-0000-4000-8000-000000000002"
    phases = _phases_for("b1", "ok")
    create_step = {
        "id": "create_asset",
        "status": "ok",
        "asset_id": asset_id,
        "asset_slug": slug,
        "asset_config": asset_config,
        "content_kind": "json",
        "extension": "json",
        "media_type": "application/json",
        "http_method": "POST",
        "proxy_body": True,
        "requires_api_key_header": True,
        "requires_provider_id_header": True,
    }
    phases["phase1"]["steps"] = [create_step]
    phases["phase3"]["steps"] = [
        {
            "id": "transfer_type_valid",
            "status": "ok",
            "transfer_type": "HttpData-PULL",
        },
        {
            "id": "transfer_final_state",
            "status": "ok",
            "final_state": "COMPLETED",
            "transfer_type": "HttpData-PULL",
        },
    ]
    phases["phase4"]["steps"] = [
        {
            "id": "post_result",
            "status": status,
            "operation": "POST",
            "http_method": "POST",
            "http_status": http_status,
            "request_body_persisted": request_body_persisted,
            "response_body_persisted": response_body_persisted,
            "download_persisted": download_persisted,
            "manifest": "phase4/post_manifest.json" if include_post_manifest else "",
            "result_artifact": "phase4/post_result.json" if include_post_result else "",
        }
    ]
    summary = {
        "suffix": suffix,
        "ds_name": "synthetic",
        "started_at": "2026-08-21T00:00:00Z",
        "phases": phases,
    }
    if with_canaries:
        summary["jwt"] = "eyJFAKECANARYTOKEN0123456789"
        phases["phase4"]["steps"][0]["authorization"] = "Bearer CANARY-AUTHORIZATION"
    write_json(run / "summary.json", summary)
    post_common = {
        "operation": "POST",
        "http_method": "POST",
        "http_status": http_status,
        "response_bytes": 32,
        "response_media_type": "application/json",
        "response_body_persisted": response_body_persisted,
        "request_body_persisted": request_body_persisted,
        "request_body_bytes": 16,
        "download_persisted": download_persisted,
        "auth_candidate_label": "authorization",
        "status": status,
        "created_at": "2026-08-21T00:00:01Z",
    }
    if include_post_result:
        write_json(run / "phase4" / "post_result.json", post_common)
    if include_post_manifest:
        write_json(
            run / "phase4" / "post_manifest.json",
            {
                **post_common,
                "suffix": suffix,
                "asset_id": asset_id,
                "agreement_id": agreement_id,
                "transfer_id": transfer_id,
                "edr_url": "https://example.invalid/public",
                "edr_url_redacted": False,
                "manifest_kind": manifest_kind,
            },
        )
    if with_canaries:
        (run / "phase1_env.sh").write_text(
            "export INGESTA_API_KEY=CANARY-API-KEY\n",
            encoding="utf-8",
        )
        write_json(
            run / "phase4" / "request_body.secret.json",
            {"payload": "CANARY-REQUEST-BODY"},
        )
        write_json(
            run / "phase4" / "response_body.secret.json",
            {"payload": "CANARY-RESPONSE-BODY"},
        )
    for phase in phases:
        write_json(run / phase / "status.json", {"status": phases[phase]["status"]})
    return run
