#!/usr/bin/env python3
"""Behavioral contract for the pinned rice-guard quality gate adapter."""

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("rguard_scan_gate", ROOT / "scripts/ci/rguard_scan_gate.py")
gate = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(gate)


class RGuardScanGateTests(unittest.TestCase):
    def test_error_findings_fail_high_threshold_but_warning_does_not(self):
        fail, reason = gate.should_fail(
            1,
            {"total_issues": 2, "by_severity": {"error": 1, "warning": 1, "info": 0}},
        )
        self.assertTrue(fail)
        self.assertIn("1 high-severity", reason)

    def test_medium_findings_are_preserved_but_do_not_fail_high_threshold(self):
        fail, reason = gate.should_fail(
            1,
            {"total_issues": 3, "by_severity": {"error": 0, "warning": 3, "info": 0}},
        )
        self.assertFalse(fail)
        self.assertIn("3 finding(s)", reason)

    def test_unsupported_threshold_fails_closed(self):
        fail, reason = gate.should_fail(
            0,
            {"total_issues": 0, "by_severity": {"error": 0, "warning": 0}},
            "low",
        )
        self.assertTrue(fail)
        self.assertIn("unsupported RICE_GUARD_FAIL_ON", reason)

    def test_scanner_failure_fails_even_without_findings(self):
        fail, reason = gate.should_fail(
            2,
            {"total_issues": 0, "by_severity": {"error": 0, "warning": 0}},
        )
        self.assertTrue(fail)
        self.assertIn("scanner or infrastructure failure", reason)

    def test_inconsistent_exit_and_summary_fails_closed(self):
        fail, reason = gate.should_fail(
            0,
            {"total_issues": 1, "by_severity": {"error": 0, "warning": 0}},
        )
        self.assertTrue(fail)
        self.assertIn("does not match", reason)


if __name__ == "__main__":
    unittest.main()
