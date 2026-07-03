#!/usr/bin/env python3
"""Package IPPCP evidence runs into a safe, shareable ZIP bundle."""

from __future__ import annotations

import argparse
import csv
import json
import shutil
import sys
import tempfile
import zipfile
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from openpyxl import load_workbook

from evidence_common import (
    ConnectorSanitizer,
    EvidenceRunLoader,
    FileEntry,
    FileIndexer,
    NOT_FOUND,
    SecretScanner,
    SummaryParser,
    build_test_specs,
    compute_sha256,
    find_repo_root,
    load_test_config,
    parse_tests_override,
    relative_to_repo,
    resolve_repo_path,
)


PACKAGE_ROOT = "ippcp_evidence_package"
MANIFEST_FIELDS = [
    "test_id",
    "suffix",
    "source_path",
    "zip_path",
    "category",
    "size_bytes",
    "sha256",
    "sanitized",
    "included",
    "exclusion_reason",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, help="YAML/JSON config with tests")
    parser.add_argument("--tests", help="Override tests as T1=SUFFIX,T2=SUFFIX")
    parser.add_argument("--excel", help="Optional Excel report to include")
    parser.add_argument("--output", help="Output .zip path")
    parser.add_argument("--export-dir", help="Base directory for timestamped exports")
    parser.add_argument("--timestamp", help="Timestamp to use for generated names, format YYYYMMDD_HHMMSS")
    parser.add_argument("--timestamp-suffix", action="store_true", help="Append timestamp before .zip")
    parser.add_argument("--repo-root", help="Repository root")
    parser.add_argument("--sanitize-connectors", action="store_true", help="Apply connector aliases to packaged copies")
    parser.add_argument("--redact-local-paths", action="store_true", default=True, help="Redact absolute local repo paths")
    parser.add_argument("--no-redact-local-paths", dest="redact_local_paths", action="store_false", help="Do not redact local paths")
    parser.add_argument("--include-downloaded-assets", action="store_true", help="Include latest downloaded assets")
    parser.add_argument("--strict", action="store_true", help="Fail on warnings/audit findings")
    parser.add_argument("--dry-run", action="store_true", help="List planned package entries without writing ZIP")
    parser.add_argument("--verbose", action="store_true")
    return parser.parse_args()


def log(message: str, verbose: bool) -> None:
    if verbose:
        print(message)


def add_manifest_row(
    rows: List[Dict[str, Any]],
    *,
    test_id: str,
    suffix: str = "",
    source_path: str = "",
    zip_path: str = "",
    category: str,
    size_bytes: int = 0,
    sha256: str = "",
    sanitized: bool = False,
    included: bool,
    exclusion_reason: str = "",
) -> None:
    rows.append(
        {
            "test_id": test_id,
            "suffix": suffix,
            "source_path": source_path,
            "zip_path": zip_path,
            "category": category,
            "size_bytes": size_bytes,
            "sha256": sha256,
            "sanitized": sanitized,
            "included": included,
            "exclusion_reason": exclusion_reason,
        }
    )


def text_suffix(path: Path) -> bool:
    return path.suffix.lower() in {".json", ".http", ".txt", ".csv", ".md"}


def sanitize_secret_key_names(text: str) -> str:
    # Packaged copies should not expose credential key names even when values are redacted.
    replacements = {
        "secretAccessKey": "redactedSecretKey",
        "accessKeyId": "redactedAccessKeyId",
        "access_token": "redacted_access_token",
        "refresh_token": "redacted_refresh_token",
        "client_secret": "redacted_client_secret",
    }
    result = text
    for source, target in replacements.items():
        result = result.replace(source, target)
    return result


def copy_for_package(
    source: Path,
    dest: Path,
    repo_root: Path,
    config: Dict[str, Any],
    sanitize_connectors: bool,
    redact_local_paths: bool,
) -> bool:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if text_suffix(source):
        text = source.read_text(encoding="utf-8", errors="replace")
        text = ConnectorSanitizer.apply(
            text,
            config.get("connector_aliases") if sanitize_connectors else {},
            redact_local_paths,
            repo_root,
        )
        text = sanitize_secret_key_names(text)
        dest.write_text(text, encoding="utf-8")
        return sanitize_connectors or redact_local_paths
    shutil.copy2(source, dest)
    return False


def package_path_for_entry(entry: FileEntry, test_folder: str) -> str:
    if entry.file_name == "summary.json":
        return f"{PACKAGE_ROOT}/{test_folder}/summary.json"
    rel = Path(entry.source_path.name)
    try:
        phase_rel = Path(*Path(entry.relative_source_path).parts[-2:])
        if phase_rel.parts[0].startswith("phase"):
            rel = phase_rel
    except Exception:
        pass
    return f"{PACKAGE_ROOT}/{test_folder}/{rel.as_posix()}"


def should_scan(entry: FileEntry) -> bool:
    return entry.source_path.suffix.lower() in {".json", ".http", ".txt", ".csv"}


def stage_entry(
    rows: List[Dict[str, Any]],
    entry: FileEntry,
    test_folder: str,
    staging_root: Path,
    repo_root: Path,
    config: Dict[str, Any],
    sanitize_connectors: bool,
    redact_local_paths: bool,
    strict: bool,
    warnings: List[str],
) -> None:
    zip_path = package_path_for_entry(entry, test_folder)
    if not entry.include_in_package:
        add_manifest_row(
            rows,
            test_id=entry.test_id,
            suffix=entry.suffix,
            source_path=entry.relative_source_path,
            category=entry.category,
            included=False,
            exclusion_reason=entry.exclusion_reason,
        )
        return

    if should_scan(entry):
        ok, reason = SecretScanner.scan_file(entry.source_path)
        if not ok:
            message = f"{entry.test_id}: excluding {entry.relative_source_path}: {reason}"
            warnings.append(message)
            add_manifest_row(
                rows,
                test_id=entry.test_id,
                suffix=entry.suffix,
                source_path=entry.relative_source_path,
                category=entry.category,
                included=False,
                exclusion_reason=reason,
            )
            return

    dest = staging_root / Path(zip_path).relative_to(PACKAGE_ROOT)
    sanitized = copy_for_package(entry.source_path, dest, repo_root, config, sanitize_connectors, redact_local_paths)
    add_manifest_row(
        rows,
        test_id=entry.test_id,
        suffix=entry.suffix,
        source_path=entry.relative_source_path,
        zip_path=zip_path,
        category=entry.category,
        size_bytes=dest.stat().st_size,
        sha256=compute_sha256(dest),
        sanitized=sanitized,
        included=True,
    )


def stage_external_file(
    rows: List[Dict[str, Any]],
    *,
    source: Path,
    zip_path: str,
    test_id: str,
    suffix: str,
    category: str,
    staging_root: Path,
    repo_root: Path,
    config: Dict[str, Any],
    sanitize_connectors: bool,
    redact_local_paths: bool,
    reason_if_missing: str = "missing",
) -> None:
    source_rel = relative_to_repo(repo_root, source)
    if not source.exists():
        add_manifest_row(rows, test_id=test_id, suffix=suffix, source_path=source_rel, category=category, included=False, exclusion_reason=reason_if_missing)
        return
    if text_suffix(source):
        ok, reason = SecretScanner.scan_file(source)
        if not ok:
            add_manifest_row(rows, test_id=test_id, suffix=suffix, source_path=source_rel, category=category, included=False, exclusion_reason=reason)
            return
    dest = staging_root / Path(zip_path).relative_to(PACKAGE_ROOT)
    sanitized = copy_for_package(source, dest, repo_root, config, sanitize_connectors, redact_local_paths)
    add_manifest_row(
        rows,
        test_id=test_id,
        suffix=suffix,
        source_path=source_rel,
        zip_path=zip_path,
        category=category,
        size_bytes=dest.stat().st_size,
        sha256=compute_sha256(dest),
        sanitized=sanitized,
        included=True,
    )


def stage_excel(
    rows: List[Dict[str, Any]],
    excel_path: Path,
    staging_root: Path,
    repo_root: Path,
    config: Dict[str, Any],
    sanitize_connectors: bool,
    redact_local_paths: bool,
) -> None:
    zip_path = f"{PACKAGE_ROOT}/{excel_path.name}"
    dest = staging_root / excel_path.name
    dest.parent.mkdir(parents=True, exist_ok=True)
    sanitized = False
    if sanitize_connectors or redact_local_paths:
        wb = load_workbook(excel_path)
        for ws in wb.worksheets:
            for row in ws.iter_rows():
                for cell in row:
                    if isinstance(cell.value, str):
                        new_value = ConnectorSanitizer.apply(
                            cell.value,
                            config.get("connector_aliases") if sanitize_connectors else {},
                            redact_local_paths,
                            repo_root,
                        )
                        if new_value != cell.value:
                            sanitized = True
                            cell.value = new_value
        wb.save(dest)
    else:
        shutil.copy2(excel_path, dest)
    add_manifest_row(
        rows,
        test_id="_package",
        source_path=relative_to_repo(repo_root, excel_path),
        zip_path=zip_path,
        category="excel",
        size_bytes=dest.stat().st_size,
        sha256=compute_sha256(dest),
        sanitized=sanitized,
        included=True,
    )


def write_package_readme(staging_root: Path, config: Dict[str, Any], specs, sanitize_connectors: bool) -> Path:
    lines = [
        "IPPCP Evidence Package",
        f"Generated at: {datetime.now().isoformat(timespec='seconds')}",
        "",
        "Contents:",
        "- Excel summary report, when provided with --excel.",
        "- Per-test evidence folders with summary.json, non-sensitive JSON artifacts, .http files, and download manifests.",
        "- package_manifest.json and package_manifest.csv list included and excluded files.",
        "",
        "Tests included:",
    ]
    for spec in specs:
        provider = spec.provider_connector
        consumer = spec.consumer_connector
        if sanitize_connectors:
            provider = ConnectorSanitizer.apply(provider, config.get("connector_aliases"), False)
            consumer = ConnectorSanitizer.apply(consumer, config.get("connector_aliases"), False)
        lines.append(f"- {spec.test_id}: workflow={spec.workflow}, suffix={spec.suffix}, provider={provider}, consumer={consumer}")
    lines.extend(
        [
            "",
            "Security exclusions:",
            "- *.sensitive.json, *.secret.json, phase*_env.sh, runtime/env/**, flujos/*/user_*.sh, and *.body are not included.",
            "- Files with unredacted credential/JWT-like values are excluded.",
            "- Original evidencias/runs/ and downloads/ files are not modified by this packaging tool.",
            "",
            "Interpreting STARTED transfers:",
            "- In B1/B2 flows, a transfer may remain STARTED while the evidence still contains a verified download.",
            "- If the manifest or summary records bytes and sha256 for save_download/storage_fetch, the material data retrieval was verified.",
        ]
    )
    if sanitize_connectors:
        lines.append("")
        lines.append("Connector aliases applied:")
        lines.append("- Private connector names were replaced with public aliases.")
        for target in (config.get("connector_aliases") or {}).values():
            lines.append(f"- {target}")
    path = staging_root / "README_PACKAGE.txt"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def write_package_manifests(staging_root: Path, rows: List[Dict[str, Any]]) -> None:
    json_path = staging_root / "package_manifest.json"
    csv_path = staging_root / "package_manifest.csv"
    json_path.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=MANIFEST_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in MANIFEST_FIELDS})


def create_zip(staging_root: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(staging_root.rglob("*")):
            if path.is_file():
                archive.write(path, f"{PACKAGE_ROOT}/{path.relative_to(staging_root).as_posix()}")


def audit_zip(zip_path: Path, sanitize_connectors: bool) -> List[str]:
    findings: List[str] = []
    forbidden = [b"secretAccessKey", b"accessKeyId"]
    if sanitize_connectors:
        forbidden.extend([b"conn-erick-test3", b"conn-edgar-test3"])
    with zipfile.ZipFile(zip_path) as archive:
        for info in archive.infolist():
            name = info.filename
            if "sensitive" in name.lower() or name.endswith(".secret.json"):
                findings.append(f"forbidden file name in zip: {name}")
            data = archive.read(info)
            for token in forbidden:
                if token in data:
                    findings.append(f"forbidden string {token.decode()} in {name}")
            try:
                text = data.decode("utf-8", errors="ignore")
            except Exception:
                text = ""
            if SecretScanner.JWT_RE.search(text):
                findings.append(f"JWT-like token in {name}")
    return findings


def print_dry_run(rows: List[Dict[str, Any]]) -> None:
    for row in rows:
        marker = "INCLUDE" if row.get("included") else "EXCLUDE"
        target = row.get("zip_path") or row.get("exclusion_reason")
        print(f"{marker}\t{row.get('test_id')}\t{row.get('source_path')}\t{target}")


def resolve_output_path(
    repo_root: Path,
    output: Optional[str],
    export_dir: Optional[str],
    timestamp: Optional[str],
    timestamp_suffix: bool,
) -> Optional[Path]:
    ts = timestamp or datetime.now().strftime("%Y%m%d_%H%M%S")
    if output:
        path = resolve_repo_path(repo_root, output)
    elif export_dir:
        return resolve_repo_path(repo_root, export_dir) / f"ippcp_evidence_package_{ts}.zip"
    else:
        return None
    if not timestamp_suffix:
        return path
    return path.with_name(f"{path.stem}_{ts}{path.suffix}")


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve() if args.repo_root else find_repo_root(Path(__file__).resolve())
    config = load_test_config(resolve_repo_path(repo_root, args.config))
    specs = build_test_specs(config, parse_tests_override(args.tests))
    defaults = config.get("defaults") or {}
    evidence_dir = resolve_repo_path(repo_root, defaults.get("evidence_dir") or "evidencias/runs")
    downloads_dir = resolve_repo_path(repo_root, defaults.get("downloads_dir") or "downloads")
    warnings: List[str] = []

    if not specs:
        print("ERROR: no tests configured", file=sys.stderr)
        return 1
    for spec in specs:
        for message in ConnectorSanitizer.validate_workflow_roles(spec, config):
            warnings.append(message)
            print(f"WARN: {message}", file=sys.stderr)

    staging_parent = Path(tempfile.mkdtemp(prefix="ippcp_bundle_"))
    staging_root = staging_parent / PACKAGE_ROOT
    staging_root.mkdir(parents=True, exist_ok=True)
    rows: List[Dict[str, Any]] = []
    indexer = FileIndexer(repo_root)
    try:
        for spec in specs:
            loader = EvidenceRunLoader(repo_root, evidence_dir, downloads_dir, spec)
            if not loader.exists():
                message = f"{spec.test_id}: missing run summary at {loader.summary_path}"
                warnings.append(message)
                print(f"WARN: {message}", file=sys.stderr)
                add_manifest_row(rows, test_id=spec.test_id, suffix=spec.suffix, source_path=relative_to_repo(repo_root, loader.summary_path), category="evidence", included=False, exclusion_reason="missing_run")
                continue
            loader.load()
            parser = loader.parser or SummaryParser(loader.summary)
            entries = indexer.collect(loader.run_dir, spec, parser)
            for entry in entries:
                stage_entry(rows, entry, spec.sheet_name, staging_root, repo_root, config, args.sanitize_connectors, args.redact_local_paths, args.strict, warnings)
            manifest = loader.canonical_manifest_path()
            if manifest:
                stage_external_file(
                    rows,
                    source=manifest,
                    zip_path=f"{PACKAGE_ROOT}/{spec.sheet_name}/downloads/latest.manifest.json",
                    test_id=spec.test_id,
                    suffix=spec.suffix,
                    category="manifest",
                    staging_root=staging_root,
                    repo_root=repo_root,
                    config=config,
                    sanitize_connectors=args.sanitize_connectors,
                    redact_local_paths=args.redact_local_paths,
                )
            if args.include_downloaded_assets:
                extension = loader.env.get("ASSET_EXTENSION")
                asset = loader.latest_asset_path(extension)
                if asset:
                    stage_external_file(
                        rows,
                        source=asset,
                        zip_path=f"{PACKAGE_ROOT}/{spec.sheet_name}/downloads/{asset.name}",
                        test_id=spec.test_id,
                        suffix=spec.suffix,
                        category="asset",
                        staging_root=staging_root,
                        repo_root=repo_root,
                        config=config,
                        sanitize_connectors=False,
                        redact_local_paths=False,
                    )

        if args.excel:
            excel_path = resolve_repo_path(repo_root, args.excel)
            if excel_path.exists():
                stage_excel(rows, excel_path, staging_root, repo_root, config, args.sanitize_connectors, args.redact_local_paths)
            else:
                add_manifest_row(rows, test_id="_package", source_path=relative_to_repo(repo_root, excel_path), category="excel", included=False, exclusion_reason="missing")
                warnings.append(f"Excel not found: {excel_path}")

        readme_path = write_package_readme(staging_root, config, specs, args.sanitize_connectors)
        add_manifest_row(
            rows,
            test_id="_package",
            source_path="generated",
            zip_path=f"{PACKAGE_ROOT}/README_PACKAGE.txt",
            category="readme",
            size_bytes=readme_path.stat().st_size,
            sha256=compute_sha256(readme_path),
            sanitized=args.sanitize_connectors,
            included=True,
        )
        # Manifest files are self-referential: their final content changes when
        # their own rows are written, so do not declare size/hash for themselves.
        for name in ("package_manifest.json", "package_manifest.csv"):
            add_manifest_row(
                rows,
                test_id="_package",
                source_path="generated",
                zip_path=f"{PACKAGE_ROOT}/{name}",
                category="package_meta",
                size_bytes="",
                sha256="",
                sanitized=False,
                included=True,
                exclusion_reason="self-referential",
            )
        write_package_manifests(staging_root, rows)

        if args.dry_run:
            print_dry_run(rows)
            return 1 if args.strict and warnings else 0

        output = resolve_output_path(repo_root, args.output, args.export_dir, args.timestamp, args.timestamp_suffix)
        if not output:
            print("ERROR: --output or --export-dir is required unless --dry-run is used", file=sys.stderr)
            return 1
        create_zip(staging_root, output)
        audit_findings = audit_zip(output, args.sanitize_connectors)
        for finding in audit_findings:
            print(f"WARN: audit: {finding}", file=sys.stderr)
        print(f"ZIP written: {relative_to_repo(repo_root, output)}")
        print(f"Included entries: {sum(1 for row in rows if row.get('included'))}")
        print(f"Excluded entries: {sum(1 for row in rows if not row.get('included'))}")
        if args.strict and (warnings or audit_findings):
            return 1
        return 0
    finally:
        shutil.rmtree(staging_parent, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
