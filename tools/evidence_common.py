#!/usr/bin/env python3
"""Common read-only helpers for IPPCP evidence export tools."""

from __future__ import annotations

import fnmatch
import hashlib
import json
import os
import re
import shlex
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

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
}
NEVER_READ_PATTERNS = ("*.sensitive.json", "*.secret.json")
EXCLUDE_PATTERNS = (
    "*.sensitive.json",
    "*.secret.json",
    "phase*_env.sh",
    "*.body",
)
PHASE_NAMES = ("phase0", "phase1", "phase1b", "phase2", "phase3", "phase3b", "phase4", "phase4b")


@dataclass
class TestSpec:
    test_id: str
    suffix: str
    sheet_name: str
    workflow: str = NOT_FOUND
    asset_type: str = NOT_FOUND
    provider_connector: str = NOT_FOUND
    consumer_connector: str = NOT_FOUND
    asset_config: str = NOT_FOUND
    expected_phases: List[str] = field(default_factory=list)


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


def build_test_specs(config: Dict[str, Any], overrides: Optional[Dict[str, str]] = None) -> List[TestSpec]:
    overrides = overrides or {}
    specs: List[TestSpec] = []
    tests = config.get("tests") or {}
    if overrides and not tests:
        tests = {test_id: {"suffix": suffix} for test_id, suffix in overrides.items()}
    for test_id, raw in tests.items():
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
                asset_config=str(raw.get("asset_config") or NOT_FOUND),
                expected_phases=list(raw.get("expected_phases") or []),
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

    def load(self) -> "EvidenceRunLoader":
        if not self.summary_path.exists():
            raise FileNotFoundError(f"Missing summary.json for {self.spec.test_id}: {self.summary_path}")
        self.summary = json.loads(self.summary_path.read_text(encoding="utf-8"))
        self.parser = SummaryParser(self.summary)
        self.env = self.load_env_files()
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

        provider_sem = semantics.get(spec.provider_connector) or {}
        consumer_sem = semantics.get(spec.consumer_connector) or {}
        provider_role = provider_sem.get("organization_role")
        consumer_role = consumer_sem.get("organization_role")
        if provider_role != workflow_expected.get("provider_role") or consumer_role != workflow_expected.get("consumer_role"):
            warnings.append(
                f"{spec.test_id}: connector roles mismatch for workflow '{spec.workflow}'. "
                f"provider {spec.provider_connector} role={provider_role}, expected={workflow_expected.get('provider_role')}; "
                f"consumer {spec.consumer_connector} role={consumer_role}, expected={workflow_expected.get('consumer_role')}"
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
                if key in DANGEROUS_KEYS:
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

