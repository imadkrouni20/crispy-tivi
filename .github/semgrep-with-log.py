#!/usr/bin/env python3
"""Run Semgrep and preserve child stderr for the uploaded quality report."""

import os
import subprocess
import sys
from pathlib import Path


def main() -> int:
    binary = os.environ.get("SEMGREP_BINARY")
    log_path = os.environ.get("SEMGREP_LOG_PATH")
    if not binary or not log_path:
        print("SEMGREP_BINARY and SEMGREP_LOG_PATH must be set", file=sys.stderr)
        return 2

    result = subprocess.run([binary, *sys.argv[1:]], capture_output=True, check=False)
    sys.stdout.buffer.write(result.stdout)
    sys.stderr.buffer.write(result.stderr)
    with Path(log_path).open("ab") as log:
        log.write(result.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
