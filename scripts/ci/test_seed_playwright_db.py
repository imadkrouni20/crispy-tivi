#!/usr/bin/env python3
"""Behavioral test for the disposable Playwright database fixture."""

import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = (
    (36, "001_initial_schema.sql"),
    (37, "002_add_xtream_stream_id.sql"),
    (39, "003_add_epg_channels_display_index.sql"),
    (40, "004_add_vod_type.sql"),
)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="crispy-playwright-db-") as temp_dir:
        database_path = Path(temp_dir) / "crispy_tivi_v2.sqlite"
        with sqlite3.connect(database_path) as database:
            database.execute("PRAGMA foreign_keys = ON")
            current_version = database.execute("PRAGMA user_version").fetchone()[0]
            for target_version, migration in MIGRATIONS:
                if target_version <= current_version:
                    continue
                migration_path = (
                    ROOT
                    / "rust/crates/crispy-core/src/database/migrations"
                    / migration
                )
                database.executescript(migration_path.read_text())
                current_version = database.execute(
                    "PRAGMA user_version"
                ).fetchone()[0]

        seed_script = ROOT / "scripts/ci/seed_playwright_db.py"
        subprocess.run(
            [sys.executable, str(seed_script), str(database_path)],
            check=True,
            cwd=ROOT,
        )

        with sqlite3.connect(database_path) as database:
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

        empty_database = Path(temp_dir) / "empty.sqlite"
        with sqlite3.connect(empty_database):
            pass
        result = subprocess.run(
            [sys.executable, str(seed_script), str(empty_database)],
            check=False,
            capture_output=True,
            text=True,
            cwd=ROOT,
        )
        assert result.returncode != 0
        assert "database schema is missing tables" in result.stderr

    print("Playwright database fixture behavior passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
