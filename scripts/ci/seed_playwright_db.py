#!/usr/bin/env python3
"""Seed deterministic, disposable media rows for the Playwright smoke test."""

import sqlite3
import sys
from pathlib import Path

MIGRATIONS = (
    (36, "001_initial_schema.sql"),
    (37, "002_add_xtream_stream_id.sql"),
    (39, "003_add_epg_channels_display_index.sql"),
    (40, "004_add_vod_type.sql"),
)


def initialize_schema(database: sqlite3.Connection) -> None:
    current_version = database.execute("PRAGMA user_version").fetchone()[0]
    migration_dir = (
        Path(__file__).resolve().parents[2]
        / "rust/crates/crispy-core/src/database/migrations"
    )
    for target_version, migration in MIGRATIONS:
        if target_version <= current_version:
            continue
        database.executescript((migration_dir / migration).read_text())
        current_version = database.execute("PRAGMA user_version").fetchone()[0]


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: seed_playwright_db.py DATABASE_PATH")

    database_path = Path(sys.argv[1])
    database_path.parent.mkdir(parents=True, exist_ok=True)

    with sqlite3.connect(database_path) as database:
        database.execute("PRAGMA foreign_keys = ON")
        initialize_schema(database)
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
