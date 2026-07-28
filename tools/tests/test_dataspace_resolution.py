from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
BASH = shutil.which("bash") or "/bin/bash"


class DataspaceResolutionTest(unittest.TestCase):
    def run_bash(
        self, body: str, repo_root: Path = REPO_ROOT
    ) -> subprocess.CompletedProcess[str]:
        env = {
            key: value
            for key, value in os.environ.items()
            if not key.startswith("IPPCP_")
            and key not in {"API_ROOT", "DS_NAME", "DS_DOMAIN"}
        }
        return subprocess.run(
            [
                BASH,
                "-c",
                f"""
set -euo pipefail
cd {shlex.quote(str(repo_root))}
export API_ROOT="$PWD"
source scripts/lib_common.sh
{body}
""",
            ],
            cwd=repo_root,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_explicit_ippcp_v2_resolves_ingesta_and_consumo(self) -> None:
        for flow in ("ingesta", "consumo"):
            with self.subTest(flow=flow):
                result = self.run_bash(
                    f"""
export IPPCP_DATASPACE=ippcp
export IPPCP_FLOW_VERSION=v2
export IPPCP_FLOW={flow}
lib_resolve_dataspace_file
source "$IPPCP_DATASPACE_FILE"
printf '%s\\n' "$IPPCP_DATASPACE_FILE"
printf '%s\\n' "$IPPCP_FLOW_DIR"
"""
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(
                    "/flujos/ippcp/export_dataspace.sh", result.stdout
                )
                self.assertIn(f"/flujos/ippcp/v2/{flow}", result.stdout)

    def test_versioned_flow_dir_infers_ippcp_dataspace(self) -> None:
        result = self.run_bash(
            """
export IPPCP_FLOW_DIR="$API_ROOT/flujos/ippcp/v2/ingesta"
export IPPCP_FLOW_VERSION=v2
export IPPCP_FLOW=ingesta
lib_resolve_dataspace_file
source "$IPPCP_DATASPACE_FILE"
printf '%s\\n' "$IPPCP_DATASPACE_FILE"
"""
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("/flujos/ippcp/export_dataspace.sh", result.stdout)

    def test_missing_context_fails_without_test3_fallback(self) -> None:
        result = self.run_bash(
            """
unset IPPCP_DATASPACE IPPCP_DATASPACE_DIR IPPCP_DATASPACE_FILE
unset IPPCP_FLOW_DIR IPPCP_FLOW IPPCP_FLOW_VERSION
lib_resolve_dataspace_file
"""
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Set IPPCP_DATASPACE=ippcp", result.stderr)
        self.assertNotIn("flujos/test3", result.stdout + result.stderr)

    def test_test3_requires_explicit_dataspace_selection(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ippcp-test3-fixture-") as temp:
            fixture_root = Path(temp)
            fixture_scripts = fixture_root / "scripts"
            fixture_dataspace = fixture_root / "flujos" / "test3"
            fixture_scripts.mkdir(parents=True)
            fixture_dataspace.mkdir(parents=True)
            shutil.copy2(
                REPO_ROOT / "scripts" / "lib_common.sh",
                fixture_scripts / "lib_common.sh",
            )
            (fixture_dataspace / "export_dataspace.sh").write_text(
                '# Synthetic test-only dataspace.\n'
                'export DS_NAME="synthetic-test3"\n',
                encoding="utf-8",
            )

            explicit_result = self.run_bash(
                """
export IPPCP_DATASPACE=test3
lib_resolve_dataspace_file
source "$IPPCP_DATASPACE_FILE"
printf '%s\\n' "$IPPCP_DATASPACE_FILE"
printf '%s\\n' "$IPPCP_DATASPACE"
printf '%s\\n' "$DS_NAME"
""",
                fixture_root,
            )
            self.assertEqual(
                explicit_result.returncode, 0, explicit_result.stderr
            )
            self.assertIn(
                str(fixture_dataspace / "export_dataspace.sh"),
                explicit_result.stdout,
            )
            self.assertIn("\ntest3\n", explicit_result.stdout)
            self.assertTrue(
                explicit_result.stdout.rstrip().endswith("synthetic-test3")
            )

            implicit_result = self.run_bash(
                """
unset IPPCP_DATASPACE IPPCP_DATASPACE_DIR IPPCP_DATASPACE_FILE
unset IPPCP_FLOW_DIR IPPCP_FLOW IPPCP_FLOW_VERSION
lib_resolve_dataspace_file
""",
                fixture_root,
            )
            self.assertNotEqual(implicit_result.returncode, 0)
            self.assertIn(
                "Set IPPCP_DATASPACE=ippcp", implicit_result.stderr
            )
            self.assertNotIn(
                "flujos/test3",
                implicit_result.stdout + implicit_result.stderr,
            )

        self.assertFalse(fixture_root.exists())


if __name__ == "__main__":
    unittest.main()
