#!/usr/bin/env python3
"""Run rice-guard and apply the configured high-severity merge threshold."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


OUTPUT_LINE = re.compile(r"^\s*Output:\s*(.+?)\s*$", re.MULTILINE)


def should_fail(
    exit_code: int,
    summary: dict[str, object],
    threshold: str = "high",
) -> tuple[bool, str]:
    """Interpret rguard status and summary without discarding its report."""
    if exit_code == 2:
        return True, "rice-guard reported a scanner or infrastructure failure"
    if exit_code not in (0, 1):
        return True, f"rice-guard exited unexpectedly with status {exit_code}"
    if threshold != "high":
        return True, f"unsupported RICE_GUARD_FAIL_ON threshold: {threshold}"

    total = summary.get("total_issues")
    severities = summary.get("by_severity")
    if not isinstance(total, int) or not isinstance(severities, dict):
        return True, "rice-guard summary has an unsupported shape"
    if any(not isinstance(severities.get(level, 0), int) for level in ("error", "warning")):
        return True, "rice-guard summary has invalid severity counts"
    if (exit_code == 0) != (total == 0):
        return True, "rice-guard exit status does not match its issue count"

    high_or_higher = severities.get("error", 0)
    if high_or_higher:
        return True, f"rice-guard found {high_or_higher} high-severity or higher issue(s)"
    return False, f"rice-guard found no high-severity issues across {total} finding(s)"


def main() -> int:
    result = subprocess.run(
        ["rguard", "scan", ".", "--diff-only"],
        check=False,
        capture_output=True,
        text=True,
    )
    print(result.stdout, end="")
    print(result.stderr, end="", file=sys.stderr)

    if result.returncode == 2:
        print("::error::rice-guard scanner or infrastructure failure", file=sys.stderr)
        return 2
    if result.returncode not in (0, 1):
        print(f"::error::unexpected rice-guard status {result.returncode}", file=sys.stderr)
        return result.returncode or 1

    match = OUTPUT_LINE.search(result.stdout)
    if match is None:
        print("::error::rice-guard did not report its output directory", file=sys.stderr)
        return 2
    report_dir = Path(match.group(1))
    summary_path = report_dir / "summary.json"
    issues_path = report_dir / "issues.json"
    try:
        summary = json.loads(summary_path.read_text())
        issues = json.loads(issues_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        print(f"::error::rice-guard report is missing or invalid: {error}", file=sys.stderr)
        return 2

    if not isinstance(issues, dict) or not isinstance(issues.get("issues"), list):
        print("::error::rice-guard issues report has an unsupported shape", file=sys.stderr)
        return 2
    if len(issues["issues"]) != summary.get("total_issues"):
        print("::error::rice-guard summary and issues report disagree", file=sys.stderr)
        return 2

    if re.search(r"(?m)^\s*semgrep\s+ok\s+\d+", result.stdout) is None:
        print("::error::rice-guard did not report a successful Semgrep scan", file=sys.stderr)
        return 2

    threshold = os.environ.get("RICE_GUARD_FAIL_ON", "high").lower()
    failed, message = should_fail(result.returncode, summary, threshold)
    if failed:
        print(f"::error::{message}", file=sys.stderr)
        return 1
    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
