#!/usr/bin/env python3
"""Behavioral test for the disposable Playwright database fixture."""

import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
def main() -> int:
    with tempfile.TemporaryDirectory(prefix="crispy-playwright-db-") as temp_dir:
        database_path = Path(temp_dir) / "crispy_tivi_v2.sqlite"
        seed_script = ROOT / "scripts/ci/seed_playwright_db.py"
        subprocess.run(
            [sys.executable, str(seed_script), str(database_path)],
            check=True,
            cwd=ROOT,
        )

        with sqlite3.connect(database_path) as database:
            assert database.execute("PRAGMA user_version").fetchone()[0] == 40
            rows = database.execute(
                "SELECT name, vod_type FROM db_movies ORDER BY vod_type"
            ).fetchall()
            assert rows == [
                ("CrispyTivi Playwright Movie", "movie"),
                ("CrispyTivi Playwright Series", "series"),
            ], rows
            assert database.execute("PRAGMA foreign_key_check").fetchall() == []

        subprocess.run(
            [sys.executable, str(seed_script), str(database_path)],
            check=True,
            cwd=ROOT,
        )
        with sqlite3.connect(database_path) as database:
            count = database.execute("SELECT COUNT(*) FROM db_movies").fetchone()[0]
            assert count == 2, count

    print("Playwright database fixture behavior passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
