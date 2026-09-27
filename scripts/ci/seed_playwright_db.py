#!/usr/bin/env python3
"""Seed deterministic, disposable media rows for the Playwright smoke test."""

import sqlite3
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: seed_playwright_db.py DATABASE_PATH")

    database_path = Path(sys.argv[1])
    if not database_path.is_file():
        raise SystemExit(f"database does not exist: {database_path}")

    with sqlite3.connect(database_path) as database:
        database.execute("PRAGMA foreign_keys = ON")
        required_tables = {"db_sources", "db_movies"}
        existing_tables = {
            row[0]
            for row in database.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
        missing = required_tables - existing_tables
        if missing:
            raise SystemExit(f"database schema is missing tables: {sorted(missing)}")

        movie_columns = {
            row[1] for row in database.execute("PRAGMA table_info(db_movies)")
        }
        if "vod_type" not in movie_columns:
            raise SystemExit("database schema is missing db_movies.vod_type")

        database.execute(
            """INSERT OR REPLACE INTO db_sources
               (id, name, source_type, url, username, password, enabled)
               VALUES (?, ?, ?, ?, ?, ?, 1)""",
            (
                "playwright-fixture-source",
                "Playwright fixture source",
                "xtream",
                "https://playwright-fixture.invalid",
                "fixture",
                "fixture",
            ),
        )
        database.executemany(
            """INSERT OR REPLACE INTO db_movies
               (id, source_id, native_id, name, stream_url, vod_type)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (
                (
                    "playwright-fixture-movie",
                    "playwright-fixture-source",
                    "1001",
                    "CrispyTivi Playwright Movie",
                    "https://playwright-fixture.invalid/movie/1001.mp4",
                    "movie",
                ),
                (
                    "playwright-fixture-series",
                    "playwright-fixture-source",
                    "2001",
                    "CrispyTivi Playwright Series",
                    "https://playwright-fixture.invalid/series/2001.mp4",
                    "series",
                ),
            ),
        )

    print(f"Seeded Playwright fixture database: {database_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
