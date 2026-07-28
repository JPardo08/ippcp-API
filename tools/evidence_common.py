#!/usr/bin/env python3
"""Common read-only helpers for IPPCP evidence export tools."""

from __future__ import annotations

import fnmatch
import hashlib
import io
import json
import os
import re
import shlex
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple
from xml.etree import ElementTree

try:
    import yaml
except ImportError:  # pragma: no cover - handled by CLI error paths
    yaml = None


NOT_FOUND = "not_found"
REDACTED_VALUES = {"", "<redacted>", "***REDACTED***", "redacted", "<REDACTED>"}
DANGEROUS_KEYS = {
    "secretAccessKey",
    "accessKeyId",
    "access_token",
    "refresh_token",
    "password",
    "client_secret",
    "authorization",
    "header:X-Api-Key",
}
NEVER_READ_PATTERNS = ("*.sensitive.json", "*.secret.json")
EXCLUDE_PATTERNS = (
    "*.sensitive.json",
    "*.secret.json",
    "phase*_env.sh",
    "*.body",
)
PHASE_NAMES = ("phase0", "phase1", "phase1b", "phase2", "phase3", "phase3b", "phase4", "phase4b")
MINIMAL_PUBLICATION_PROFILE = "minimal_publication"
T4_NOT_RECORDED = "not_recorded"
T4_NOT_APPLICABLE = "not_applicable"
T4_WITHHELD_HASH = "<withheld-pending-publication-approval>"
T4_PLACEHOLDER_IDENTIFIERS = {
    "run_id": "<run-id>",
    "asset_id": "<asset-id>",
    "contract_definition_id": "<contract-definition-id>",
    "negotiation_id": "<negotiation-id>",
    "agreement_id": "<agreement-id>",
    "transfer_process_id": "<transfer-process-id>",
}
T4_PUBLIC_FLOW_LABEL = "Ingestion API v2"
T4_ALLOWED_STATUSES = {"ok", "failed", "skipped", "not_found", "passed", T4_NOT_RECORDED}
T4_OOXML_ALLOWED_PARTS = {
    "[Content_Types].xml",
    "_rels/.rels",
    "docProps/app.xml",
    "docProps/core.xml",
    "xl/_rels/workbook.xml.rels",
    "xl/styles.xml",
    "xl/theme/theme1.xml",
    "xl/workbook.xml",
}
T4_OOXML_ALLOWED_PART_PATTERNS = (
    "xl/worksheets/sheet*.xml",
    "xl/worksheets/_rels/sheet*.xml.rels",
    "xl/sharedStrings.xml",
)


@dataclass
class TestSpec:
    test_id: str
    suffix: str
    sheet_name: str
    workflow: str = NOT_FOUND
    asset_type: str = NOT_FOUND
    provider_connector: str = NOT_FOUND
    consumer_connector: str = NOT_FOUND
    technical_provider_connector: str = NOT_FOUND
    technical_consumer_connector: str = NOT_FOUND
    asset_config: str = NOT_FOUND
    expected_phases: List[str] = field(default_factory=list)
    publication_profile: str = ""
    evidence_role: str = ""


@dataclass
class FileEntry:
    test_id: str
    suffix: str
    source_path: Path
    relative_source_path: str
    phase: str
    file_name: str
    is_sensitive: bool
    include_in_package: bool
    exclusion_reason: str = ""
    description: str = ""
    http_status_file: str = ""
    related_step: str = ""
    category: str = "evidence"


@dataclass(frozen=True)
class T4PublicationModel:
    """Canonical, presentation-neutral T4 minimal-publication values."""

    test_id: str
    public_flow_label: str
    flow_type: str
    asset_type: str
    evidence_role: str
    technical_provider_connector: str
    technical_consumer_connector: str
    phase_statuses: Dict[str, str]
    technical_status: str
    download_status: str
    byte_count: int
    sha256_algorithm: str
    sha256_verified: bool
    sha256_value: str
    semantic_validation_status: str
    semantic_validation_source: str
    execution_identifiers: Dict[str, str]
    payload_included: bool
    not_recorded: str = T4_NOT_RECORDED
    not_applicable: str = T4_NOT_APPLICABLE


def canonical_t4_status(value: Any) -> str:
    normalized = str(value or NOT_FOUND).lower()
    return normalized if normalized in T4_ALLOWED_STATUSES else NOT_FOUND


def build_t4_publication_model(
    *,
    test_id: str,
    asset_type: str,
    evidence_role: str,
    technical_provider_connector: str,
    technical_consumer_connector: str,
    phase_statuses: Dict[str, Any],
    download_status: Any,
    byte_count: Any,
    sha256_verified: bool,
    semantic_validation_status: Any = T4_NOT_RECORDED,
    semantic_validation_recorded: bool = False,
) -> T4PublicationModel:
    """Build and validate the pure canonical T4 publication model."""
    phases = {
        phase: canonical_t4_status(phase_statuses.get(phase))
        for phase in ("phase0", "phase1", "phase2", "phase3", "phase4")
    }
    try:
        safe_byte_count = max(0, int(byte_count))
    except (TypeError, ValueError):
        safe_byte_count = 0
    model = T4PublicationModel(
        test_id=str(test_id),
        public_flow_label=T4_PUBLIC_FLOW_LABEL,
        flow_type="ingestion-api-v2",
        asset_type=str(asset_type),
        evidence_role=str(evidence_role),
        technical_provider_connector=str(technical_provider_connector),
        technical_consumer_connector=str(technical_consumer_connector),
        phase_statuses=phases,
        technical_status="Validated",
        download_status=canonical_t4_status(download_status),
        byte_count=safe_byte_count,
        sha256_algorithm="SHA-256",
        sha256_verified=bool(sha256_verified),
        sha256_value=T4_WITHHELD_HASH,
        semantic_validation_status=(
            canonical_t4_status(semantic_validation_status)
            if semantic_validation_recorded
            else T4_NOT_RECORDED
        ),
        semantic_validation_source=(
            "allowlisted-metadata" if semantic_validation_recorded else "not-recorded"
        ),
        execution_identifiers=dict(T4_PLACEHOLDER_IDENTIFIERS),
        payload_included=False,
    )
    findings = validate_t4_publication_model(model)
    if findings:
        raise ValueError(f"invalid T4 publication model: {findings}")
    return model


def validate_t4_publication_model(model: T4PublicationModel) -> List[str]:
    findings: List[str] = []
    expected_phases = {"phase0", "phase1", "phase2", "phase3", "phase4"}
    if set(model.phase_statuses) != expected_phases:
        findings.append("phase status inventory differs from canonical phases")
    for phase, status in model.phase_statuses.items():
        if status not in T4_ALLOWED_STATUSES:
            findings.append(f"{phase}: invalid status")
    if model.download_status not in T4_ALLOWED_STATUSES:
        findings.append("invalid download status")
    if model.semantic_validation_status not in T4_ALLOWED_STATUSES:
        findings.append("invalid semantic validation status")
    if model.byte_count < 0:
        findings.append("byte count must be non-negative")
    if model.technical_status != "Validated":
        findings.append("technical status differs from approved capability label")
    if model.public_flow_label != T4_PUBLIC_FLOW_LABEL:
        findings.append("public flow label differs from canonical value")
    if model.sha256_value != T4_WITHHELD_HASH:
        findings.append("hash value is not withheld")
    if model.execution_identifiers != T4_PLACEHOLDER_IDENTIFIERS:
        findings.append("execution identifiers differ from placeholders")
    if model.payload_included:
        findings.append("payload must be excluded")
    for value in (
        model.test_id,
        model.public_flow_label,
        model.flow_type,
        model.asset_type,
        model.evidence_role,
        model.technical_provider_connector,
        model.technical_consumer_connector,
        model.semantic_validation_source,
        *model.phase_statuses.values(),
        *model.execution_identifiers.values(),
    ):
        findings.extend(PublicationScanner.findings(str(value)))
    return findings


def workbook_cell_snapshot(workbook: Any) -> Dict[str, Dict[str, Any]]:
    """Return exact non-empty cell values by sheet and coordinate."""
    return {
        worksheet.title: {
            cell.coordinate: cell.value
            for row in worksheet.iter_rows()
            for cell in row
            if cell.value not in (None, "")
        }
        for worksheet in workbook.worksheets
    }


def audit_t4_workbook(
    workbook: Any,
    *,
    expected_cells: Dict[str, Dict[str, Any]],
    protected_cells: Optional[Dict[str, Dict[str, Any]]] = None,
    t4_only: bool,
    canaries: Optional[Iterable[str]] = None,
) -> List[str]:
    """Audit workbook object surfaces and exact T4 cell projection."""
    findings: List[str] = []
    protected_cells = protected_cells or {}
    actual_snapshot = workbook_cell_snapshot(workbook)
    expected_sheet_names = set(expected_cells)
    if t4_only and set(actual_snapshot) != expected_sheet_names:
        findings.append(
            f"sheet inventory differs: {sorted(actual_snapshot)} != {sorted(expected_sheet_names)}"
        )
    for worksheet in workbook.worksheets:
        if worksheet.sheet_state != "visible":
            findings.append(f"{worksheet.title}: non-visible sheet")
        for index, dimension in worksheet.row_dimensions.items():
            if dimension.hidden:
                findings.append(f"{worksheet.title}: hidden row {index}")
        for index, dimension in worksheet.column_dimensions.items():
            if dimension.hidden:
                findings.append(f"{worksheet.title}: hidden column {index}")
        for row in worksheet.iter_rows():
            for cell in row:
                if cell.comment is not None:
                    findings.append(f"{worksheet.title}!{cell.coordinate}: comment")
                if cell.hyperlink is not None:
                    findings.append(f"{worksheet.title}!{cell.coordinate}: hyperlink")
                if cell.data_type == "f" or (
                    isinstance(cell.value, str) and cell.value.startswith("=")
                ):
                    findings.append(f"{worksheet.title}!{cell.coordinate}: formula")
                if isinstance(cell.value, str):
                    for finding in SecretScanner.text_secret_findings(cell.value):
                        findings.append(
                            f"{worksheet.title}!{cell.coordinate}: {finding}"
                        )
                    if PublicationScanner.CANARY_RE.search(cell.value):
                        findings.append(
                            f"{worksheet.title}!{cell.coordinate}: generic_canary"
                        )
                    for canary in canaries or ():
                        if canary and canary in cell.value:
                            findings.append(
                                f"{worksheet.title}!{cell.coordinate}: canary:{canary}"
                            )
    defined_names = list(workbook.defined_names.values())
    if defined_names:
        findings.append("defined names present")
    for field in ("title", "subject", "creator", "keywords", "description", "category"):
        value = getattr(workbook.properties, field, None)
        if value:
            for finding in PublicationScanner.findings(str(value), canaries):
                findings.append(f"property {field}: {finding}")
            for finding in SecretScanner.text_secret_findings(str(value)):
                findings.append(f"property {field}: {finding}")
            for canary in canaries or ():
                if canary and canary in str(value):
                    findings.append(f"property {field}: canary:{canary}")
    custom_properties = getattr(workbook, "custom_doc_props", ())
    if len(custom_properties):
        findings.append("custom document properties present")
    for sheet_name, cells in expected_cells.items():
        actual = actual_snapshot.get(sheet_name, {})
        for coordinate, value in cells.items():
            if isinstance(value, str):
                for finding in PublicationScanner.findings(value, canaries):
                    findings.append(f"{sheet_name}!{coordinate}: {finding}")
        if t4_only:
            if actual != cells:
                findings.append(f"{sheet_name}: T4 projection differs from allowlist")
        else:
            for coordinate, value in cells.items():
                if actual.get(coordinate) != value:
                    findings.append(
                        f"{sheet_name}!{coordinate}: T4 projection differs from allowlist"
                    )
    for sheet_name, cells in protected_cells.items():
        actual = actual_snapshot.get(sheet_name, {})
        for coordinate, value in cells.items():
            if actual.get(coordinate) != value:
                findings.append(f"{sheet_name}!{coordinate}: protected cell changed")
        introduced = set(actual) - set(cells) - set(expected_cells.get(sheet_name, {}))
        if introduced:
            findings.append(
                f"{sheet_name}: unexpected cells introduced: {sorted(introduced)}"
            )
    return findings


def audit_t4_xlsx_bytes(
    content: bytes,
    *,
    t4_sheet_names: Set[str],
    canaries: Optional[Iterable[str]] = None,
) -> List[str]:
    """Audit serialized OOXML parts, relationships, and T4 worksheet text."""
    findings: List[str] = []
    try:
        archive = zipfile.ZipFile(io.BytesIO(content))
    except zipfile.BadZipFile:
        return ["invalid XLSX ZIP"]
    with archive:
        names = {info.filename for info in archive.infolist() if not info.is_dir()}
        for name in sorted(names):
            if name not in T4_OOXML_ALLOWED_PARTS and not matches_any(
                name, T4_OOXML_ALLOWED_PART_PATTERNS
            ):
                findings.append(f"unexpected OOXML part: {name}")
            lowered = name.lower()
            if (
                "externallink" in lowered
                or "vbaproject" in lowered
                or "customxml" in lowered
                or lowered.endswith((".bin", ".vml"))
            ):
                findings.append(f"forbidden OOXML part: {name}")
            data = archive.read(name)
            text = data.decode("utf-8", errors="ignore")
            if PublicationScanner.CANARY_RE.search(text):
                findings.append(f"generic_canary in {name}")
            for canary in canaries or ():
                if canary and canary in text:
                    findings.append(f"canary:{canary} in {name}")
            if name.endswith(".rels"):
                try:
                    root = ElementTree.fromstring(data)
                except ElementTree.ParseError:
                    findings.append(f"invalid relationship XML: {name}")
                    continue
                for relationship in root:
                    target = relationship.attrib.get("Target", "")
                    rel_type = relationship.attrib.get("Type", "")
                    if (
                        relationship.attrib.get("TargetMode") == "External"
                        or "externalLink" in rel_type
                        or target.startswith(("http:", "https:", "file:"))
                    ):
                        findings.append(f"external relationship in {name}")
        sheet_parts: Dict[str, str] = {}
        try:
            workbook_root = ElementTree.fromstring(archive.read("xl/workbook.xml"))
            rels_root = ElementTree.fromstring(
                archive.read("xl/_rels/workbook.xml.rels")
            )
            rel_targets = {
                rel.attrib["Id"]: rel.attrib.get("Target", "")
                for rel in rels_root
            }
            namespace = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
            rel_id = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
            for sheet in workbook_root.findall(f".//{namespace}sheet"):
                target = rel_targets.get(sheet.attrib.get(rel_id, ""), "")
                if target.startswith("/"):
                    part = target.lstrip("/")
                else:
                    part = "xl/" + target.lstrip("/")
                sheet_parts[sheet.attrib.get("name", "")] = part
        except (KeyError, ElementTree.ParseError):
            findings.append("invalid workbook relationship mapping")
        for sheet_name in t4_sheet_names:
            part = sheet_parts.get(sheet_name)
            if not part or part not in names:
                findings.append(f"missing T4 worksheet part: {sheet_name}")
                continue
            try:
                sheet_root = ElementTree.fromstring(archive.read(part))
                text = "\n".join(sheet_root.itertext())
            except ElementTree.ParseError:
                findings.append(f"invalid worksheet XML: {part}")
                continue
            for finding in PublicationScanner.findings(text, canaries):
                findings.append(f"{finding} in {part}")
        if "xl/sharedStrings.xml" in names:
            try:
                shared_root = ElementTree.fromstring(
                    archive.read("xl/sharedStrings.xml")
                )
                shared = "\n".join(shared_root.itertext())
            except ElementTree.ParseError:
                findings.append("invalid shared strings XML")
                shared = ""
            for finding in PublicationScanner.findings(shared, canaries):
                findings.append(f"{finding} in xl/sharedStrings.xml")
    return findings


def find_repo_root(start_path: Optional[Path] = None) -> Path:
    """Find the repo root by walking upward until project markers are found."""
    current = (start_path or Path.cwd()).resolve()
    if current.is_file():
        current = current.parent
    for candidate in (current, *current.parents):
        if (candidate / ".git").exists() and (candidate / "scripts").exists():
            return candidate
    raise FileNotFoundError(f"Could not find repo root from {current}")


def load_test_config(path: Path) -> Dict[str, Any]:
    """Load YAML/JSON config and normalize test specs."""
    if not path.exists():
        raise FileNotFoundError(f"Config not found: {path}")
    if path.suffix.lower() in {".yaml", ".yml"}:
        if yaml is None:
            raise RuntimeError("PyYAML is required to read YAML configs")
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    else:
        data = json.loads(path.read_text(encoding="utf-8"))
    tests = data.get("tests") or {}
    if not isinstance(tests, dict):
        raise ValueError("Config field 'tests' must be a mapping")
    return data


def parse_tests_override(value: Optional[str]) -> Dict[str, str]:
    if not value:
        return {}
    result: Dict[str, str] = {}
    for item in value.split(","):
        if not item.strip():
            continue
        if "=" not in item:
            raise ValueError(f"Invalid --tests item '{item}', expected TEST_ID=SUFFIX")
        test_id, suffix = item.split("=", 1)
        result[test_id.strip()] = suffix.strip()
    return result


def parse_only_tests(value: Optional[str]) -> Set[str]:
    if not value:
        return set()
    return {item.strip() for item in value.split(",") if item.strip()}


def build_test_specs(
    config: Dict[str, Any],
    overrides: Optional[Dict[str, str]] = None,
    only_tests: Optional[Set[str]] = None,
) -> List[TestSpec]:
    overrides = overrides or {}
    only_tests = only_tests or set()
    specs: List[TestSpec] = []
    tests = config.get("tests") or {}
    if overrides and not tests:
        tests = {test_id: {"suffix": suffix} for test_id, suffix in overrides.items()}
    for test_id, raw in tests.items():
        if only_tests and test_id not in only_tests:
            continue
        raw = raw or {}
        suffix = overrides.get(test_id, str(raw.get("suffix", "")))
        if not suffix:
            continue
        specs.append(
            TestSpec(
                test_id=test_id,
                suffix=str(suffix),
                sheet_name=str(raw.get("sheet_name") or test_id),
                workflow=str(raw.get("workflow") or NOT_FOUND),
                asset_type=str(raw.get("asset_type") or NOT_FOUND),
                provider_connector=str(raw.get("provider_connector") or NOT_FOUND),
                consumer_connector=str(raw.get("consumer_connector") or NOT_FOUND),
                technical_provider_connector=str(raw.get("technical_provider_connector") or NOT_FOUND),
                technical_consumer_connector=str(raw.get("technical_consumer_connector") or NOT_FOUND),
                asset_config=str(raw.get("asset_config") or NOT_FOUND),
                expected_phases=list(raw.get("expected_phases") or []),
                publication_profile=str(raw.get("publication_profile") or ""),
                evidence_role=str(raw.get("evidence_role") or ""),
            )
        )
    return specs


def resolve_repo_path(repo_root: Path, maybe_relative: str) -> Path:
    path = Path(maybe_relative)
    return path if path.is_absolute() else repo_root / path


def relative_to_repo(repo_root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def compute_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class PhaseEnvParser:
    """Parse generated env files without evaluating shell code."""

    @staticmethod
    def parse_file(path: Path) -> Dict[str, str]:
        values: Dict[str, str] = {}
        if not path.exists() or path.name.endswith(".sensitive.json"):
            return values
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            stripped = line.strip()
            if not stripped.startswith("export ") or "=" not in stripped:
                continue
            try:
                parts = shlex.split(stripped[len("export ") :], posix=True)
            except ValueError:
                continue
            for part in parts:
                if "=" not in part:
                    continue
                key, value = part.split("=", 1)
                if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key):
                    values[key] = value
        return values


class SummaryParser:
    def __init__(self, summary: Dict[str, Any]) -> None:
        self.summary = summary
        self.phases: Dict[str, Any] = summary.get("phases") or {}

    def phase(self, phase: str) -> Dict[str, Any]:
        return self.phases.get(phase) or {}

    def phase_status(self, phase: str) -> str:
        return str(self.phase(phase).get("status") or NOT_FOUND)

    def phase_steps(self, phase: str) -> List[Dict[str, Any]]:
        steps = self.phase(phase).get("steps") or []
        return steps if isinstance(steps, list) else []

    def all_steps(self) -> Iterable[Tuple[str, Dict[str, Any]]]:
        for phase in PHASE_NAMES:
            for step in self.phase_steps(phase):
                yield phase, step

    def get_step(self, phase: str, step_id: str) -> Optional[Dict[str, Any]]:
        for step in self.phase_steps(phase):
            if step.get("id") == step_id:
                return step
        return None

    def find_step(self, step_id: str) -> Optional[Tuple[str, Dict[str, Any]]]:
        for phase, step in self.all_steps():
            if step.get("id") == step_id:
                return phase, step
        return None

    def detect_workflow_kind(self) -> str:
        if "phase1b" in self.phases:
            return "b2"
        if "phase1" in self.phases:
            return "b1"
        return NOT_FOUND

    def artifact_step_map(self) -> Dict[str, str]:
        result: Dict[str, str] = {}
        for _, step in self.all_steps():
            step_id = str(step.get("id") or "")
            for key in ("artifact", "request", "offer_artifact", "attempts_artifact", "preview_artifact", "manifest"):
                artifact = step.get(key)
                if isinstance(artifact, str):
                    result[artifact] = step_id
                    result[f"{artifact}.json"] = step_id
                    result[f"{artifact}.http"] = step_id
        return result


class EvidenceRunLoader:
    def __init__(self, repo_root: Path, evidence_dir: Path, downloads_dir: Path, spec: TestSpec) -> None:
        self.repo_root = repo_root
        self.evidence_dir = evidence_dir
        self.downloads_dir = downloads_dir
        self.spec = spec
        self.run_dir = evidence_dir / spec.suffix
        self.summary_path = self.run_dir / "summary.json"
        self.summary: Dict[str, Any] = {}
        self.parser: Optional[SummaryParser] = None
        self.env: Dict[str, str] = {}

    def exists(self) -> bool:
        return self.summary_path.exists()

    def load(self, include_env: bool = True) -> "EvidenceRunLoader":
        if not self.summary_path.exists():
            raise FileNotFoundError(f"Missing summary.json for {self.spec.test_id}: {self.summary_path}")
        self.summary = json.loads(self.summary_path.read_text(encoding="utf-8"))
        self.parser = SummaryParser(self.summary)
        self.env = self.load_env_files() if include_env else {}
        return self

    def load_env_files(self) -> Dict[str, str]:
        merged: Dict[str, str] = {}
        for name in ("phase1_env.sh", "phase1b_env.sh", "phase2_env.sh", "phase3_env.sh", "phase3b_env.sh"):
            merged.update(PhaseEnvParser.parse_file(self.run_dir / name))
        return merged

    def asset_id(self) -> str:
        if self.env.get("ASSET_ID"):
            return self.env["ASSET_ID"]
        parser = self.parser or SummaryParser(self.summary)
        for _, step in parser.all_steps():
            if step.get("asset_id"):
                return str(step["asset_id"])
        return NOT_FOUND

    def canonical_manifest_path(self) -> Optional[Path]:
        asset_id = self.asset_id()
        if asset_id == NOT_FOUND:
            return None
        return self.downloads_dir / "manifests" / asset_id / "latest.manifest.json"

    def latest_asset_path(self, extension: Optional[str] = None) -> Optional[Path]:
        asset_id = self.asset_id()
        if asset_id == NOT_FOUND:
            return None
        asset_dir = self.downloads_dir / "assets" / asset_id
        if extension:
            candidate = asset_dir / f"latest.{extension}"
            return candidate if candidate.exists() else None
        if not asset_dir.exists():
            return None
        for candidate in sorted(asset_dir.glob("latest.*")):
            return candidate
        return None


def _load_json_object(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def _find_first_value(data: Any, keys: Set[str]) -> Any:
    if isinstance(data, dict):
        for key, value in data.items():
            if key in keys and value not in (None, ""):
                return value
        for value in data.values():
            found = _find_first_value(value, keys)
            if found not in (None, ""):
                return found
    elif isinstance(data, list):
        for value in data:
            found = _find_first_value(value, keys)
            if found not in (None, ""):
                return found
    return None


def extract_t4_publication_model(
    loader: EvidenceRunLoader, spec: TestSpec
) -> T4PublicationModel:
    """Extract only allowlisted T4 evidence inputs into the shared model."""
    parser = loader.parser or SummaryParser(loader.summary)
    manifest = _load_json_object(
        loader.run_dir / "phase4" / "download_manifest.json"
    )
    semantic = _load_json_object(
        loader.run_dir / "phase4" / "semantic_validation.json"
    )
    source_hash = _find_first_value(manifest, {"sha256", "sha_256"})
    download_step = parser.get_step("phase4", "save_download") or {}
    return build_t4_publication_model(
        test_id=spec.test_id,
        asset_type=spec.asset_type,
        evidence_role=spec.evidence_role,
        technical_provider_connector=spec.technical_provider_connector,
        technical_consumer_connector=spec.technical_consumer_connector,
        phase_statuses={
            phase: parser.phase_status(phase)
            for phase in ("phase0", "phase1", "phase2", "phase3", "phase4")
        },
        download_status=download_step.get("status") or parser.phase_status("phase4"),
        byte_count=_find_first_value(
            manifest, {"bytes", "size_bytes", "byte_count"}
        ),
        sha256_verified=isinstance(source_hash, str) and bool(source_hash.strip()),
        semantic_validation_status=semantic.get("status"),
        semantic_validation_recorded=bool(semantic),
    )


class ConnectorSanitizer:
    @staticmethod
    def derived_aliases(aliases: Dict[str, str]) -> Dict[str, str]:
        derived = dict(aliases or {})
        for source, target in aliases.items():
            derived[f"test3-{source}"] = f"test3-{target}"
        return derived

    @staticmethod
    def validate_workflow_roles(spec: TestSpec, config: Dict[str, Any]) -> List[str]:
        warnings: List[str] = []
        aliases = config.get("connector_aliases") or {}
        semantics = config.get("connector_semantics") or {}
        expected = config.get("expected_workflow_roles") or {}

        for connector, alias in aliases.items():
            public_alias = (semantics.get(connector) or {}).get("public_alias")
            if public_alias and public_alias != alias:
                warnings.append(
                    f"{spec.test_id}: connector_aliases[{connector}]={alias} differs from "
                    f"connector_semantics[{connector}].public_alias={public_alias}"
                )

        workflow_expected = expected.get(spec.workflow)
        if not workflow_expected:
            warnings.append(f"{spec.test_id}: no expected_workflow_roles entry for workflow '{spec.workflow}'")
            return warnings

        provider_connector = (
            spec.technical_provider_connector
            if spec.technical_provider_connector != NOT_FOUND
            else spec.provider_connector
        )
        consumer_connector = (
            spec.technical_consumer_connector
            if spec.technical_consumer_connector != NOT_FOUND
            else spec.consumer_connector
        )
        provider_sem = semantics.get(provider_connector) or {}
        consumer_sem = semantics.get(consumer_connector) or {}
        provider_role = provider_sem.get("organization_role")
        consumer_role = consumer_sem.get("organization_role")
        if provider_role != workflow_expected.get("provider_role") or consumer_role != workflow_expected.get("consumer_role"):
            warnings.append(
                f"{spec.test_id}: connector roles mismatch for workflow '{spec.workflow}'. "
                f"provider {provider_connector} role={provider_role}, expected={workflow_expected.get('provider_role')}; "
                f"consumer {consumer_connector} role={consumer_role}, expected={workflow_expected.get('consumer_role')}"
            )
        return warnings

    @staticmethod
    def apply(
        text: str,
        aliases: Optional[Dict[str, str]],
        redact_local_paths: bool = True,
        repo_root: Optional[Path] = None,
    ) -> str:
        result = text
        replacements = ConnectorSanitizer.derived_aliases(aliases or {})
        for source in sorted(replacements, key=len, reverse=True):
            result = result.replace(source, replacements[source])
        if redact_local_paths:
            if repo_root:
                result = result.replace(str(repo_root.resolve()), "<repo-root>")
            result = re.sub(r"/Users/[^\s\"']*/ippcp_API", "<repo-root>", result)
        return result


class SecretScanner:
    JWT_RE = re.compile(r"eyJ[A-Za-z0-9_-]{20,}")
    API_KEY_HEADER_RE = re.compile(
        r"""(?i)header:X-Api-Key["']?\s*[:=]\s*["']?([^"',}\s]+)"""
    )

    @staticmethod
    def is_redacted(value: Any) -> bool:
        if value is None:
            return True
        if isinstance(value, str):
            return value.strip() in REDACTED_VALUES
        return False

    @classmethod
    def json_secret_findings(cls, data: Any, path: str = "") -> List[str]:
        findings: List[str] = []
        if isinstance(data, dict):
            for key, value in data.items():
                current_path = f"{path}.{key}" if path else str(key)
                if str(key).lower().endswith("header:x-api-key"):
                    if value != "<redacted>":
                        findings.append(current_path)
                elif key in DANGEROUS_KEYS:
                    if key == "authorization":
                        if isinstance(value, str) and cls.JWT_RE.search(value) and not cls.is_redacted(value):
                            findings.append(current_path)
                    elif not cls.is_redacted(value):
                        findings.append(current_path)
                findings.extend(cls.json_secret_findings(value, current_path))
        elif isinstance(data, list):
            for idx, item in enumerate(data):
                findings.extend(cls.json_secret_findings(item, f"{path}[{idx}]"))
        return findings

    @classmethod
    def text_secret_findings(cls, text: str) -> List[str]:
        findings: List[str] = []
        if cls.JWT_RE.search(text):
            findings.append("jwt_like_token")
        for match in cls.API_KEY_HEADER_RE.finditer(text):
            if match.group(1) != "<redacted>":
                findings.append("header:X-Api-Key")
        for key in ("secretAccessKey", "accessKeyId", "access_token", "refresh_token", "client_secret"):
            if key in text:
                findings.append(key)
        return findings

    @classmethod
    def scan_file(cls, path: Path) -> Tuple[bool, str]:
        if matches_any(path.name, NEVER_READ_PATTERNS):
            return False, "never_read_sensitive"
        try:
            if path.suffix == ".json":
                data = json.loads(path.read_text(encoding="utf-8", errors="replace"))
                findings = cls.json_secret_findings(data)
            elif path.suffix in {".txt", ".http", ".csv"}:
                findings = cls.text_secret_findings(path.read_text(encoding="utf-8", errors="replace"))
            else:
                findings = []
        except Exception as exc:
            return False, f"scan_error:{exc.__class__.__name__}"
        if findings:
            return False, "secret_key_detected:" + ",".join(findings[:5])
        return True, ""


class PublicationScanner:
    """Detect values forbidden by the minimal publication profile."""

    URL_RE = re.compile(r"""https?://[^\s"'<>]+""", re.IGNORECASE)
    ABSOLUTE_PATH_RE = re.compile(r"""(?<![A-Za-z0-9])/(?:Users|home|private|tmp|var)/[^\s"'<>]+""")
    AUTHORIZATION_VALUE_RE = re.compile(
        r"""(?i)\b(?:authorization|edr[_ -]?authorization)\b["']?\s*[:=]\s*["']?(?!<redacted>|<withheld)[^\s"',}]+"""
    )
    PASSWORD_VALUE_RE = re.compile(
        r"""(?i)\bpassword\b["']?\s*[:=]\s*["']?(?!<redacted>|<withheld)[^\s"',}]+"""
    )
    API_KEY_VALUE_RE = re.compile(
        r"""(?i)\b(?:INGESTA_API_KEY|X-Api-Key|header:X-Api-Key)\b["']?\s*[:=]\s*["']?(?!<redacted>|<withheld)[^\s"',}]+"""
    )
    UUID_RE = re.compile(
        r"""\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\b"""
    )
    REAL_SUFFIX_RE = re.compile(r"""\b[0-9]{9,12}\b""")
    CANARY_RE = re.compile(r"""\bCANARY[-_][A-Za-z0-9_-]*""", re.IGNORECASE)

    @classmethod
    def findings(cls, text: str, canaries: Optional[Iterable[str]] = None) -> List[str]:
        findings: List[str] = []
        checks = (
            ("jwt_like_token", SecretScanner.JWT_RE),
            ("authorization_value", cls.AUTHORIZATION_VALUE_RE),
            ("password_value", cls.PASSWORD_VALUE_RE),
            ("api_key_value", cls.API_KEY_VALUE_RE),
            ("concrete_url", cls.URL_RE),
            ("absolute_path", cls.ABSOLUTE_PATH_RE),
            ("uuid", cls.UUID_RE),
            ("real_suffix", cls.REAL_SUFFIX_RE),
            ("generic_canary", cls.CANARY_RE),
        )
        for label, pattern in checks:
            if pattern.search(text):
                findings.append(label)
        for canary in canaries or ():
            if canary and canary in text:
                findings.append(f"canary:{canary}")
        return findings


def validate_allowlisted_json(data: Any, schema: Any, path: str = "") -> List[str]:
    """Return unknown or structurally invalid fields for an exact JSON allowlist."""
    if schema is None:
        return []
    if not isinstance(schema, dict):
        return [f"{path or '<root>'}: invalid allowlist schema"]
    if not isinstance(data, dict):
        return [f"{path or '<root>'}: expected object"]

    findings: List[str] = []
    allowed = set(schema)
    for key in data:
        current = f"{path}.{key}" if path else str(key)
        if key not in allowed:
            findings.append(f"{current}: unknown field")
            continue
        findings.extend(validate_allowlisted_json(data[key], schema[key], current))
    for key in allowed - set(data):
        current = f"{path}.{key}" if path else str(key)
        findings.append(f"{current}: missing field")
    return findings


def matches_any(name: str, patterns: Iterable[str]) -> bool:
    return any(fnmatch.fnmatch(name, pattern) for pattern in patterns)


def describe_file(path: Path) -> str:
    name = path.name
    if name == "summary.json":
        return "Run summary"
    if name.endswith(".http"):
        return "HTTP status code"
    if "jwt_claims" in name:
        return "Redacted JWT claims"
    if "redacted" in name:
        return "Redacted JSON artifact"
    if "download_manifest" in name or name == "latest.manifest.json":
        return "Download manifest"
    if "context" in name:
        return "Execution context"
    return "Evidence artifact"


class FileIndexer:
    def __init__(self, repo_root: Path) -> None:
        self.repo_root = repo_root

    def classify(self, path: Path, run_dir: Path, spec: TestSpec, parser: Optional[SummaryParser] = None) -> FileEntry:
        rel_repo = relative_to_repo(self.repo_root, path)
        rel_run = path.relative_to(run_dir).as_posix() if path.is_relative_to(run_dir) else rel_repo
        first_part = rel_run.split("/", 1)[0]
        phase = first_part if first_part in PHASE_NAMES else ("run" if path.name == "summary.json" else "downloads")
        file_name = path.name
        is_sensitive = matches_any(file_name, NEVER_READ_PATTERNS)
        include, reason = self.package_decision(path, rel_run, is_sensitive)
        http_status_file = ""
        if path.suffix == ".json":
            http_candidate = path.with_suffix(".http")
            if http_candidate.exists():
                http_status_file = relative_to_repo(self.repo_root, http_candidate)
        related_step = ""
        if parser:
            artifact_map = parser.artifact_step_map()
            related_step = artifact_map.get(rel_run) or artifact_map.get(rel_run.removesuffix(".json")) or ""
        return FileEntry(
            test_id=spec.test_id,
            suffix=spec.suffix,
            source_path=path,
            relative_source_path=rel_repo,
            phase=phase,
            file_name=file_name,
            is_sensitive=is_sensitive,
            include_in_package=include,
            exclusion_reason=reason,
            description=describe_file(path),
            http_status_file=http_status_file,
            related_step=related_step,
            category="evidence",
        )

    def package_decision(self, path: Path, rel_run: str, is_sensitive: bool) -> Tuple[bool, str]:
        if is_sensitive:
            return False, "sensitive_filename"
        if matches_any(path.name, EXCLUDE_PATTERNS):
            if path.name.endswith("_env.sh"):
                return False, "runtime_env"
            if path.suffix == ".body":
                return False, "binary_upload_payload"
            return False, "sensitive_filename"
        if "runtime/env/" in rel_run or rel_run.startswith("runtime/env/"):
            return False, "runtime_env"
        if re.match(r"phase[0-9b]*_env\.sh$", path.name):
            return False, "runtime_env"
        if path.name == "summary.json":
            return True, ""
        if rel_run.startswith(PHASE_NAMES) and path.suffix in {".json", ".http", ".txt"}:
            return True, ""
        return False, "not_in_allowlist"

    def collect(self, run_dir: Path, spec: TestSpec, parser: Optional[SummaryParser] = None) -> List[FileEntry]:
        entries: List[FileEntry] = []
        if not run_dir.exists():
            return entries
        for root, _, files in os.walk(run_dir):
            for file_name in sorted(files):
                path = Path(root) / file_name
                entries.append(self.classify(path, run_dir, spec, parser))
        return entries

