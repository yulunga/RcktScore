#!/usr/bin/env python3
"""Validate RcktScore SQL migration numbering and checked-in checksums."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from dataclasses import dataclass
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SCHEMA_DIRECTORY = REPOSITORY_ROOT / "backend" / "schema"
MANIFEST_PATH = SCHEMA_DIRECTORY / "checksums.sha256"
FILENAME_PATTERN = re.compile(r"^(?P<version>[0-9]{3})_[a-z0-9_]+[.]sql$")


@dataclass(frozen=True)
class Migration:
    version: int
    filename: str
    checksum: str


def discover_migrations() -> tuple[list[Migration], list[str]]:
    migrations: list[Migration] = []
    errors: list[str] = []
    versions: dict[int, str] = {}

    for path in sorted(SCHEMA_DIRECTORY.glob("*.sql")):
        match = FILENAME_PATTERN.fullmatch(path.name)
        if match is None:
            errors.append(f"invalid migration filename: {path.name}")
            continue

        version = int(match.group("version"))
        if version in versions:
            errors.append(
                f"duplicate migration version {version:03d}: "
                f"{versions[version]} and {path.name}"
            )
        else:
            versions[version] = path.name

        content = path.read_bytes()
        if not content.strip():
            errors.append(f"empty migration file: {path.name}")
        migrations.append(
            Migration(
                version=version,
                filename=path.name,
                checksum=hashlib.sha256(content).hexdigest(),
            )
        )

    migrations.sort(key=lambda migration: migration.version)
    if migrations:
        expected = set(range(1, migrations[-1].version + 1))
        actual = {migration.version for migration in migrations}
        missing = sorted(expected - actual)
        if missing:
            errors.append(
                "missing migration versions: "
                + ", ".join(f"{version:03d}" for version in missing)
            )

    return migrations, errors


def render_manifest(migrations: list[Migration]) -> str:
    return "".join(
        f"{migration.checksum}  {migration.filename}\n"
        for migration in migrations
    )


def verify_manifest(migrations: list[Migration]) -> list[str]:
    if not MANIFEST_PATH.exists():
        return [f"checksum manifest is missing: {MANIFEST_PATH.relative_to(REPOSITORY_ROOT)}"]

    expected = render_manifest(migrations)
    actual = MANIFEST_PATH.read_text(encoding="utf-8")
    if actual == expected:
        return []

    expected_lines = set(expected.splitlines())
    actual_lines = set(actual.splitlines())
    errors = ["migration checksum manifest is out of date"]
    for line in sorted(actual_lines - expected_lines):
        errors.append(f"manifest-only or changed entry: {line}")
    for line in sorted(expected_lines - actual_lines):
        errors.append(f"required entry: {line}")
    return errors


def write_manifest(migrations: list[Migration]) -> list[str]:
    current_by_filename = {
        migration.filename: migration.checksum for migration in migrations
    }
    errors: list[str] = []

    if MANIFEST_PATH.exists():
        for line_number, line in enumerate(
            MANIFEST_PATH.read_text(encoding="utf-8").splitlines(), start=1
        ):
            parts = line.split()
            if len(parts) != 2:
                errors.append(f"invalid manifest line {line_number}: {line}")
                continue

            checksum, filename = parts
            current_checksum = current_by_filename.get(filename)
            if current_checksum is None:
                errors.append(
                    f"refusing to remove checksum-pinned migration: {filename}"
                )
            elif current_checksum != checksum:
                errors.append(
                    f"refusing to replace checksum for existing migration: {filename}"
                )

    if errors:
        return errors

    MANIFEST_PATH.write_text(render_manifest(migrations), encoding="utf-8")
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        nargs="?",
        choices=("verify", "manifest", "write-manifest"),
        default="verify",
    )
    arguments = parser.parse_args()

    migrations, errors = discover_migrations()
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    if arguments.command == "manifest":
        print(render_manifest(migrations), end="")
        return 0

    if arguments.command == "write-manifest":
        manifest_errors = write_manifest(migrations)
        if manifest_errors:
            for error in manifest_errors:
                print(f"ERROR: {error}", file=sys.stderr)
            return 1
        print(f"Wrote {MANIFEST_PATH.relative_to(REPOSITORY_ROOT)}")
        return 0

    manifest_errors = verify_manifest(migrations)
    if manifest_errors:
        for error in manifest_errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(
        f"Verified {len(migrations)} migrations "
        f"(001-{migrations[-1].version:03d}); versions and checksums are unique."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
