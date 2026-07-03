#!/usr/bin/env python3
"""Export IPPCP JSON evidence runs to a readable Excel workbook."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

from evidence_common import (
    ConnectorSanitizer,
    EvidenceRunLoader,
    FileEntry,
    FileIndexer,
    NOT_FOUND,
    SecretScanner,
    SummaryParser,
    build_test_specs,
    find_repo_root,
    load_test_config,
    parse_tests_override,
    relative_to_repo,
    resolve_repo_path,
)


SUMMARY_COLUMNS = [
    "test_id",
    "workflow",
    "asset_type",
    "provider_connector",
    "consumer_connector",
    "suffix",
    "asset_id",
    "vocab_id",
    "access_policy_id",
    "contract_policy_id",
    "contract_definition_id",
    "offer_policy_id",
    "negotiation_id",
    "agreement_id",
    "transfer_id",
    "transfer_type",
    "transfer_state",
    "download_status",
    "download_file",
    "bytes",
    "sha256",
    "summary_json",
    "manifest_json",
    "overall_status",
    "notes",
]

CHECKLIST_REQUIREMENTS = [
    "provider authentication",
    "consumer authentication",
    "asset created/published",
    "policy created",
    "contract definition created",
    "catalog discovery",
    "offer policy selected/validated",
    "contract negotiation started",
    "negotiation finalized / agreement obtained",
    "transfer started/completed",
    "data downloaded/fetched",
    "manifest/hash generated",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", help="YAML/JSON config with tests")
    parser.add_argument("--tests", help="Override tests as T1=SUFFIX,T2=SUFFIX")
    parser.add_argument("--repo-root", help="Repository root")
    parser.add_argument("--evidence-dir", help="Evidence runs directory")
    parser.add_argument("--downloads-dir", help="Downloads directory")
    parser.add_argument("--output", help="Output .xlsx path")
    parser.add_argument("--export-dir", help="Base directory for timestamped exports")
    parser.add_argument("--timestamp", help="Timestamp to use for generated names, format YYYYMMDD_HHMMSS")
    parser.add_argument("--timestamp-suffix", action="store_true", help="Append timestamp before .xlsx")
    parser.add_argument("--strict", action="store_true", help="Fail on warnings or incomplete tests")
    parser.add_argument("--sanitize-connectors", action="store_true", help="Apply connector aliases in output")
    parser.add_argument("--redact-local-paths", action="store_true", help="Redact absolute repo paths in output")
    parser.add_argument("--verbose", action="store_true")
    return parser.parse_args()


def warn(message: str, warnings: List[str], verbose: bool = True) -> None:
    warnings.append(message)
    if verbose:
        print(f"WARN: {message}", file=sys.stderr)


def nested_id_from_file(path: Path) -> str:
    if not path.exists() or path.name.endswith(".sensitive.json"):
        return NOT_FOUND
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return NOT_FOUND
    return str(data.get("@id") or data.get("id") or NOT_FOUND)


def step_value(parser: SummaryParser, phase: str, step_id: str, key: str) -> str:
    step = parser.get_step(phase, step_id)
    if not step:
        return NOT_FOUND
    value = step.get(key)
    return str(value) if value not in (None, "") else NOT_FOUND


def first_step_value(parser: SummaryParser, candidates: List[Tuple[str, str, str]]) -> str:
    for phase, step_id, key in candidates:
        value = step_value(parser, phase, step_id, key)
        if value != NOT_FOUND:
            return value
    return NOT_FOUND


def manifest_data(path: Optional[Path]) -> Dict[str, Any]:
    if not path or not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def phase_is_ok(parser: SummaryParser, phase: str) -> bool:
    return parser.phase_status(phase) == "ok"


def compute_overall_status(spec, parser: SummaryParser, row: Dict[str, Any]) -> Tuple[str, str]:
    expected = spec.expected_phases or list(parser.phases.keys())
    missing = [phase for phase in expected if phase not in parser.phases]
    if missing:
        return "INCOMPLETE", f"Missing phases: {', '.join(missing)}"
    failed = [phase for phase in expected if parser.phase_status(phase) != "ok"]
    if failed:
        return "FAIL", f"Non-ok phases: {', '.join(failed)}"

    transfer_state = row.get("transfer_state")
    download_status = row.get("download_status")
    has_download = download_status == "ok" and str(row.get("sha256") or NOT_FOUND) != NOT_FOUND
    if not has_download:
        negotiation = parser.find_step("negotiation_finalized")
        if negotiation and negotiation[1].get("status") == "ok":
            return "PARTIAL", "Negotiation ok but download evidence missing or failed"
        return "INCOMPLETE", "Download evidence missing"

    if parser.detect_workflow_kind() == "b2" and transfer_state == "STARTED":
        return "PASS_WITH_NOTE", "B2 transfer is STARTED, but phase4b.storage_fetch verified consumer MinIO download with hash"
    if parser.detect_workflow_kind() == "b1" and transfer_state == "STARTED":
        return "PASS_WITH_NOTE", "B1 transfer is STARTED, but data_consumed and save_download verified download with hash"
    return "PASS", ""


def build_summary_row(loader: EvidenceRunLoader, spec, repo_root: Path) -> Dict[str, Any]:
    parser = loader.parser or SummaryParser(loader.summary)
    manifest_path = loader.canonical_manifest_path()
    manifest = manifest_data(manifest_path)
    kind = parser.detect_workflow_kind()
    publish_phase = "phase1b" if kind == "b2" else "phase1"
    transfer_phase = "phase3b" if kind == "b2" else "phase3"
    download_phase = "phase4b" if kind == "b2" else "phase4"
    download_step = "storage_fetch" if kind == "b2" else "save_download"

    row: Dict[str, Any] = {
        "test_id": spec.test_id,
        "workflow": spec.workflow,
        "asset_type": spec.asset_type,
        "provider_connector": spec.provider_connector,
        "consumer_connector": spec.consumer_connector,
        "suffix": loader.summary.get("suffix") or spec.suffix,
        "asset_id": loader.asset_id(),
        "vocab_id": loader.env.get("VOCAB_ID") or nested_id_from_file(loader.run_dir / publish_phase / "10_create_vocabulary.json"),
        "access_policy_id": loader.env.get("ACCESS_POLICY_ID") or nested_id_from_file(loader.run_dir / publish_phase / "11_create_access_policy.json"),
        "contract_policy_id": loader.env.get("CONTRACT_POLICY_ID") or nested_id_from_file(loader.run_dir / publish_phase / "12_create_contract_policy.json"),
        "contract_definition_id": loader.env.get("CD_ID") or first_existing_id(loader.run_dir / publish_phase, "create_contract_definition"),
        "offer_policy_id": first_step_value(parser, [("phase2", "selected_ids", "offer_policy_id")]),
        "negotiation_id": first_step_value(
            parser,
            [
                ("phase2", "contract_negotiation_started", "neg_id"),
                ("phase2", "negotiation_finalized", "neg_id"),
            ],
        ),
        "agreement_id": first_step_value(
            parser,
            [
                ("phase2", "negotiation_finalized", "agreement_id"),
                ("phase2", "get_contract_agreement", "agreement_id"),
            ],
        ),
        "transfer_id": first_step_value(
            parser,
            [
                (transfer_phase, "transfer_started", "transfer_id"),
                (transfer_phase, "transfer_final_state", "transfer_id"),
            ],
        ),
        "transfer_type": first_found(
            first_step_value(
                parser,
                [
                    (transfer_phase, "transfer_started", "transfer_type"),
                    (transfer_phase, "transfer_type_valid", "transfer_type"),
                    (transfer_phase, "transfer_final_state", "transfer_type"),
                ],
            ),
            manifest.get("transfer_type"),
        ),
        "transfer_state": first_found(
            first_step_value(parser, [(transfer_phase, "transfer_final_state", "final_state")]),
            manifest.get("consumer_transfer_state"),
        ),
        "download_status": first_step_value(parser, [(download_phase, download_step, "status")]),
        "download_file": first_found(
            first_step_value(
                parser,
                [
                    (download_phase, download_step, "latest_file"),
                    (download_phase, download_step, "download_file"),
                ],
            ),
            manifest.get("latest_file"),
        ),
        "bytes": first_found(first_step_value(parser, [(download_phase, download_step, "bytes")]), manifest.get("bytes")),
        "sha256": first_found(first_step_value(parser, [(download_phase, download_step, "sha256")]), manifest.get("sha256")),
        "summary_json": relative_to_repo(repo_root, loader.summary_path),
        "manifest_json": relative_to_repo(repo_root, manifest_path) if manifest_path and manifest_path.exists() else NOT_FOUND,
        "overall_status": "",
        "notes": "",
    }
    status, note = compute_overall_status(spec, parser, row)
    row["overall_status"] = status
    row["notes"] = note
    return {key: normalize_cell(row.get(key)) for key in SUMMARY_COLUMNS}


def first_existing_id(phase_dir: Path, name_fragment: str) -> str:
    if not phase_dir.exists():
        return NOT_FOUND
    for path in sorted(phase_dir.glob(f"*{name_fragment}*.json")):
        if path.name.endswith("_request.json") or path.name.endswith(".sensitive.json"):
            continue
        value = nested_id_from_file(path)
        if value != NOT_FOUND:
            return value
    return NOT_FOUND


def normalize_cell(value: Any) -> Any:
    if value is None or value == "":
        return NOT_FOUND
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False, sort_keys=True)
    return value


def first_found(*values: Any) -> Any:
    for value in values:
        if value not in (None, "", NOT_FOUND):
            return value
    return NOT_FOUND


def sanitize_value(value: Any, config: Dict[str, Any], repo_root: Path, sanitize: bool, redact_paths: bool) -> Any:
    if not isinstance(value, str):
        return value
    aliases = config.get("connector_aliases") if sanitize else {}
    return ConnectorSanitizer.apply(value, aliases, redact_paths, repo_root)


def append_table(ws, title: str, headers: List[str], rows: List[List[Any]]) -> None:
    if ws.max_row > 1 or ws["A1"].value:
        ws.append([])
    ws.append([title])
    ws.cell(ws.max_row, 1).font = Font(bold=True, size=12)
    ws.append(headers)
    for cell in ws[ws.max_row]:
        cell.font = Font(bold=True)
        cell.fill = PatternFill("solid", fgColor="D9EAF7")
    for row in rows:
        ws.append(row)


def build_phase_rows(parser: SummaryParser) -> List[List[Any]]:
    rows: List[List[Any]] = []
    for phase in parser.phases.keys():
        steps = parser.phase_steps(phase)
        timestamps = [str(step.get("ts")) for step in steps if step.get("ts")]
        rows.append([phase, parser.phase_status(phase), len(steps), min(timestamps) if timestamps else "", max(timestamps) if timestamps else ""])
    return rows


def build_step_rows(parser: SummaryParser) -> List[List[Any]]:
    rows: List[List[Any]] = []
    base_keys = {"id", "status", "ts", "http"}
    for phase, step in parser.all_steps():
        metadata = {key: value for key, value in step.items() if key not in base_keys}
        rows.append(
            [
                phase,
                step.get("id", NOT_FOUND),
                step.get("status", NOT_FOUND),
                step.get("ts", ""),
                step.get("http", ""),
                json.dumps(metadata, ensure_ascii=False, sort_keys=True) if metadata else "",
            ]
        )
    return rows


def build_artifact_rows(entries: List[FileEntry]) -> List[List[Any]]:
    rows: List[List[Any]] = []
    for entry in entries:
        if entry.is_sensitive:
            continue
        rows.append([entry.phase, entry.relative_source_path, entry.http_status_file, entry.related_step, entry.description])
    return rows


def build_manifest_rows(loader: EvidenceRunLoader) -> List[List[Any]]:
    rows: List[List[Any]] = []
    manifest = manifest_data(loader.canonical_manifest_path())
    for key in sorted(manifest):
        rows.append([key, normalize_cell(manifest[key])])
    return rows


def checklist_rows(loader: EvidenceRunLoader, spec, summary_row: Dict[str, Any]) -> List[Dict[str, Any]]:
    parser = loader.parser or SummaryParser(loader.summary)
    kind = parser.detect_workflow_kind()

    def status_for(steps: List[Tuple[str, str]], require_all: bool = False) -> Tuple[str, str, str]:
        matched = []
        for phase, step_id in steps:
            step = parser.get_step(phase, step_id)
            if step:
                matched.append((phase, step))
        if not matched:
            return "not_found", "", ""
        ok_count = sum(1 for _, step in matched if step.get("status") == "ok")
        ok = ok_count == len(steps) if require_all else ok_count > 0
        phase, step = matched[-1]
        artifact = step.get("artifact") or step.get("manifest") or ""
        return ("ok" if ok else "fail", artifact, f"{phase}.{step.get('id')}")

    mappings = {
        "provider authentication": [("phase0", "jwt_provider"), ("phase1", "jwt_provider")],
        "consumer authentication": [("phase0", "jwt_consumer"), ("phase2", "jwt_consumer"), ("phase3", "jwt_consumer")],
        "asset created/published": [("phase1", "create_asset"), ("phase1b", "get_asset")],
        "policy created": [("phase1", "create_access_policy"), ("phase1", "create_contract_policy"), ("phase1b", "create_access_policy"), ("phase1b", "create_contract_policy")],
        "contract definition created": [("phase1", "create_contract_definition"), ("phase1b", "create_contract_definition")],
        "catalog discovery": [("phase1", "self_catalog"), ("phase2", "remote_catalog")],
        "offer policy selected/validated": [("phase2", "offer_policy_valid"), ("phase2", "catalog_asset_found")],
        "contract negotiation started": [("phase2", "contract_negotiation_started")],
        "negotiation finalized / agreement obtained": [("phase2", "negotiation_finalized"), ("phase2", "get_contract_agreement")],
        "transfer started/completed": [("phase3", "transfer_started"), ("phase3", "transfer_final_state"), ("phase3b", "transfer_started"), ("phase3b", "transfer_final_state")],
        "data downloaded/fetched": [("phase3", "data_consumed"), ("phase4", "save_download"), ("phase4b", "storage_fetch")],
        "manifest/hash generated": [("phase4", "save_download"), ("phase4b", "storage_fetch")],
    }
    rows = []
    for requirement in CHECKLIST_REQUIREMENTS:
        status, artifact, evidence_step = status_for(mappings[requirement])
        notes = ""
        if requirement == "transfer started/completed" and summary_row["overall_status"] == "PASS_WITH_NOTE":
            status = "ok"
            notes = summary_row["notes"]
        if requirement == "manifest/hash generated" and summary_row.get("sha256") not in ("", NOT_FOUND):
            status = "ok"
            artifact = summary_row.get("manifest_json", artifact)
        rows.append(
            {
                "test_id": spec.test_id,
                "requirement": requirement,
                "status": status,
                "evidence_file": artifact,
                "evidence_step": evidence_step,
                "notes": notes or (f"Workflow kind: {kind}" if status == "ok" else ""),
            }
        )
    return rows


def package_manifest_rows(entries: List[FileEntry], loader: EvidenceRunLoader, include_assets: bool = False) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for entry in entries:
        rows.append(
            {
                "test_id": entry.test_id,
                "file_path": entry.relative_source_path,
                "category": entry.category,
                "include_in_package": entry.include_in_package,
                "reason": entry.exclusion_reason or ("recommended" if entry.include_in_package else "excluded"),
                "size_bytes": entry.source_path.stat().st_size if entry.source_path.exists() and not entry.is_sensitive else 0,
            }
        )
    manifest = loader.canonical_manifest_path()
    if manifest and manifest.exists():
        rows.append(
            {
                "test_id": loader.spec.test_id,
                "file_path": relative_to_repo(loader.repo_root, manifest),
                "category": "manifest",
                "include_in_package": True,
                "reason": "canonical download manifest",
                "size_bytes": manifest.stat().st_size,
            }
        )
    if include_assets:
        asset = loader.latest_asset_path()
        if asset and asset.exists():
            rows.append(
                {
                    "test_id": loader.spec.test_id,
                    "file_path": relative_to_repo(loader.repo_root, asset),
                    "category": "asset",
                    "include_in_package": True,
                    "reason": "downloaded asset",
                    "size_bytes": asset.stat().st_size,
                }
            )
    return rows


def apply_workbook_format(wb: Workbook) -> None:
    status_fills = {
        "PASS": "D8EAD2",
        "ok": "D8EAD2",
        "PASS_WITH_NOTE": "FFF2CC",
        "PARTIAL": "FFF2CC",
        "FAIL": "F4CCCC",
        "fail": "F4CCCC",
        "INCOMPLETE": "F4CCCC",
    }
    for ws in wb.worksheets:
        ws.freeze_panes = "A2"
        if ws.max_row >= 1 and ws.max_column >= 1:
            ws.auto_filter.ref = ws.dimensions
        for row in ws.iter_rows():
            for cell in row:
                if cell.row == 1 or (isinstance(cell.value, str) and cell.value in {"Datos generales", "IDs principales", "Estado por fase", "Pasos (summary)", "Artefactos por fase", "Manifest", "Notas de interpretación"}):
                    cell.font = Font(bold=True)
                if isinstance(cell.value, str) and cell.value in status_fills:
                    cell.fill = PatternFill("solid", fgColor=status_fills[cell.value])
                if cell.column_letter in {"Y", "F"} or cell.value and isinstance(cell.value, str) and len(cell.value) > 80:
                    cell.alignment = Alignment(wrap_text=True, vertical="top")
        for col_idx in range(1, ws.max_column + 1):
            max_len = 8
            for cell in ws.iter_cols(min_col=col_idx, max_col=col_idx):
                for item in cell:
                    max_len = max(max_len, min(len(str(item.value or "")), 60))
            ws.column_dimensions[get_column_letter(col_idx)].width = max_len + 2


def write_rows(ws, headers: List[str], rows: List[Dict[str, Any]], config: Dict[str, Any], repo_root: Path, sanitize: bool, redact_paths: bool) -> None:
    ws.append(headers)
    for cell in ws[1]:
        cell.font = Font(bold=True)
        cell.fill = PatternFill("solid", fgColor="D9EAD3")
    for row in rows:
        ws.append([sanitize_value(row.get(header, ""), config, repo_root, sanitize, redact_paths) for header in headers])


def resolve_output_path(
    repo_root: Path,
    output: Optional[str],
    export_dir: Optional[str],
    timestamp: Optional[str],
    timestamp_suffix: bool,
) -> Path:
    ts = timestamp or datetime.now().strftime("%Y%m%d_%H%M%S")
    if output:
        path = resolve_repo_path(repo_root, output)
    elif export_dir:
        path = resolve_repo_path(repo_root, export_dir) / f"ippcp_evidence_summary_{ts}.xlsx"
        return path
    else:
        raise ValueError("--output or --export-dir is required")
    if not timestamp_suffix:
        return path
    return path.with_name(f"{path.stem}_{ts}{path.suffix}")


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve() if args.repo_root else find_repo_root(Path(__file__).resolve())
    config_path = resolve_repo_path(repo_root, args.config) if args.config else None
    config = load_test_config(config_path) if config_path else {"tests": {}}
    overrides = parse_tests_override(args.tests)
    specs = build_test_specs(config, overrides)
    defaults = config.get("defaults") or {}
    evidence_dir = resolve_repo_path(repo_root, args.evidence_dir or defaults.get("evidence_dir") or "evidencias/runs")
    downloads_dir = resolve_repo_path(repo_root, args.downloads_dir or defaults.get("downloads_dir") or "downloads")
    warnings: List[str] = []

    if not specs:
        print("ERROR: no tests configured", file=sys.stderr)
        return 1

    for spec in specs:
        for message in ConnectorSanitizer.validate_workflow_roles(spec, config):
            warn(message, warnings, args.verbose)

    wb = Workbook()
    wb.remove(wb.active)
    summary_rows: List[Dict[str, Any]] = []
    raw_index_rows: List[Dict[str, Any]] = []
    checklist_all: List[Dict[str, Any]] = []
    package_rows: List[Dict[str, Any]] = []
    indexer = FileIndexer(repo_root)

    for spec in specs:
        loader = EvidenceRunLoader(repo_root, evidence_dir, downloads_dir, spec)
        if not loader.exists():
            message = f"{spec.test_id}: missing run summary at {loader.summary_path}"
            warn(message, warnings, True)
            if args.strict:
                continue
            summary_rows.append({column: NOT_FOUND for column in SUMMARY_COLUMNS} | {"test_id": spec.test_id, "suffix": spec.suffix, "overall_status": "INCOMPLETE", "notes": message})
            continue
        try:
            loader.load()
        except Exception as exc:
            message = f"{spec.test_id}: cannot load evidence: {exc}"
            warn(message, warnings, True)
            if args.strict:
                continue
            summary_rows.append({column: NOT_FOUND for column in SUMMARY_COLUMNS} | {"test_id": spec.test_id, "suffix": spec.suffix, "overall_status": "FAIL", "notes": message})
            continue
        if str(loader.summary.get("suffix")) != spec.suffix:
            warn(f"{spec.test_id}: summary suffix differs from config suffix", warnings, args.verbose)
        parser = loader.parser or SummaryParser(loader.summary)
        entries = indexer.collect(loader.run_dir, spec, parser)
        row = build_summary_row(loader, spec, repo_root)
        summary_rows.append(row)

        ws = wb.create_sheet(spec.sheet_name[:31])
        append_table(
            ws,
            "Datos generales",
            ["field", "value"],
            [
                ["test_id", spec.test_id],
                ["workflow", spec.workflow],
                ["asset_type", spec.asset_type],
                ["asset_config", spec.asset_config],
                ["ds_name", loader.summary.get("ds_name", NOT_FOUND)],
                ["started_at", loader.summary.get("started_at", NOT_FOUND)],
                ["provider_connector", spec.provider_connector],
                ["consumer_connector", spec.consumer_connector],
            ],
        )
        append_table(ws, "IDs principales", ["field", "value"], [[key, row[key]] for key in SUMMARY_COLUMNS if key.endswith("_id") or key in {"asset_id", "sha256"}])
        append_table(ws, "Estado por fase", ["phase", "status", "step_count", "first_ts", "last_ts"], build_phase_rows(parser))
        append_table(ws, "Pasos (summary)", ["phase", "step_id", "status", "ts", "http", "metadata"], build_step_rows(parser))
        append_table(ws, "Artefactos por fase", ["phase", "artifact", "http_status", "related_step", "description"], build_artifact_rows(entries))
        append_table(ws, "Manifest", ["field", "value"], build_manifest_rows(loader))
        append_table(ws, "Notas de interpretación", ["field", "value"], [["overall_status", row["overall_status"]], ["notes", row["notes"]]])

        for entry in entries:
            raw_index_rows.append(
                {
                    "test_id": entry.test_id,
                    "suffix": entry.suffix,
                    "phase": entry.phase,
                    "file_path": entry.relative_source_path,
                    "file_name": entry.file_name,
                    "is_sensitive": entry.is_sensitive,
                    "include_in_package": entry.include_in_package,
                    "description": entry.description,
                    "http_status_file": entry.http_status_file,
                    "related_step": entry.related_step,
                }
            )
        checklist_all.extend(checklist_rows(loader, spec, row))
        package_rows.extend(package_manifest_rows(entries, loader))

    ws_summary = wb.create_sheet("Summary", 0)
    write_rows(ws_summary, SUMMARY_COLUMNS, summary_rows, config, repo_root, args.sanitize_connectors, args.redact_local_paths)
    ws_raw = wb.create_sheet("Raw JSON Index")
    write_rows(
        ws_raw,
        ["test_id", "suffix", "phase", "file_path", "file_name", "is_sensitive", "include_in_package", "description", "http_status_file", "related_step"],
        raw_index_rows,
        config,
        repo_root,
        args.sanitize_connectors,
        args.redact_local_paths,
    )
    ws_check = wb.create_sheet("Evidence Checklist")
    write_rows(ws_check, ["test_id", "requirement", "status", "evidence_file", "evidence_step", "notes"], checklist_all, config, repo_root, args.sanitize_connectors, args.redact_local_paths)
    ws_package = wb.create_sheet("Package Manifest")
    write_rows(ws_package, ["test_id", "file_path", "category", "include_in_package", "reason", "size_bytes"], package_rows, config, repo_root, args.sanitize_connectors, args.redact_local_paths)

    for ws in wb.worksheets:
        for row in ws.iter_rows():
            for cell in row:
                cell.value = sanitize_value(cell.value, config, repo_root, args.sanitize_connectors, args.redact_local_paths)

    apply_workbook_format(wb)
    out = resolve_output_path(repo_root, args.output, args.export_dir, args.timestamp, args.timestamp_suffix)
    out.parent.mkdir(parents=True, exist_ok=True)
    wb.save(out)
    print(f"Excel written: {relative_to_repo(repo_root, out)}")
    for row in summary_rows:
        print(f"{row.get('test_id')}: {row.get('overall_status')} ({row.get('suffix')})")

    if args.strict and warnings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
