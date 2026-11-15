#!/usr/bin/env python3
"""Inspect and safely restore the WordPress files needed by the local stack."""

from __future__ import annotations

import argparse
import gzip
import io
import re
import shutil
import sys
import tarfile
from collections import Counter
from pathlib import Path, PurePosixPath
from typing import BinaryIO, Iterable


VERSION_PATTERN = re.compile(r"\$wp_version\s*=\s*['\"]([^'\"]+)['\"]")
CREATE_DATABASE_PATTERN = re.compile(
    r"\bCREATE\s+DATABASE\s+"
    r"(?:(?:/\*!\d+\s+IF\s+NOT\s+EXISTS\s*\*/\s*)|"
    r"(?:IF\s+NOT\s+EXISTS\s+))?"
    r"`?([A-Za-z0-9_]+)`?",
    re.IGNORECASE,
)
USE_DATABASE_PATTERN = re.compile(r"\bUSE\s+`?([A-Za-z0-9_]+)`?\s*;", re.IGNORECASE)
CREATE_TABLE_PATTERN = re.compile(
    r"\bCREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?([A-Za-z0-9_]+)`?",
    re.IGNORECASE,
)
SAFE_IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z0-9_]+$")
CORE_TABLE_SUFFIXES = ("options", "posts", "users", "postmeta", "usermeta")
RESTORE_PATHS = (
    "wp-content/plugins",
    "wp-content/uploads",
    "wp-content/themes/neve",
)


class ArchiveError(Exception):
    """Raised when a supplied archive is not safe or has an unknown format."""


def normalized_name(name: str) -> str:
    parts = PurePosixPath(name).parts
    parts = tuple(part for part in parts if part not in ("", "/", "."))
    if ".." in parts:
        raise ArchiveError(f"Archive contains an unsafe path: {name}")
    return "/".join(parts)


def open_tar(path: str, mode: str = "r:gz") -> tarfile.TarFile:
    try:
        return tarfile.open(path, mode)
    except (OSError, tarfile.TarError) as error:
        raise ArchiveError(f"Cannot read archive: {error}") from error


def find_home_root(archive_path: str) -> tuple[str, str]:
    roots: dict[str, str] = {}
    with open_tar(archive_path, "r|gz") as archive:
        for member in archive:
            name = normalized_name(member.name)
            suffix = "wp-includes/version.php"
            if not name.endswith(suffix) or not member.isfile():
                continue
            root = name[: -(len(suffix) + 1)]
            file_object = archive.extractfile(member)
            if file_object is None:
                raise ArchiveError("Cannot read wp-includes/version.php.")
            version_file = file_object.read(128 * 1024 + 1)
            if len(version_file) > 128 * 1024:
                raise ArchiveError("wp-includes/version.php is unexpectedly large.")
            match = VERSION_PATTERN.search(version_file.decode("utf-8", errors="replace"))
            if match is None:
                raise ArchiveError("Cannot detect the WordPress version.")
            roots[root] = match.group(1)
    if len(roots) != 1:
        raise ArchiveError(
            "The home archive must contain exactly one WordPress core tree."
        )
    root, version = next(iter(roots.items()))
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,2}", version):
        raise ArchiveError(f"Invalid WordPress version in archive: {version}")
    return root, version


def is_selected_path(relative_path: str) -> bool:
    return any(
        relative_path == selected or relative_path.startswith(selected + "/")
        for selected in RESTORE_PATHS
    )


def extract_home(
    archive_path: str,
    destination_path: str,
    expected_version: str,
    expected_root: str,
) -> None:
    destination_argument = Path(destination_path)
    if destination_argument.is_symlink():
        raise ArchiveError("The WordPress content destination must not be a symlink.")
    destination = destination_argument.resolve()
    if destination.exists() and any(destination.iterdir()):
        raise ArchiveError("The WordPress content destination is not empty.")
    destination.mkdir(parents=True, exist_ok=True)

    required_directories = set(RESTORE_PATHS)
    found_directories: set[str] = set()
    version_found = False
    extracted_paths: set[str] = set()

    with open_tar(archive_path, "r|gz") as archive:
        for member in archive:
            name = normalized_name(member.name)
            if name == f"{expected_root}/wp-includes/version.php" and member.isfile():
                file_object = archive.extractfile(member)
                if file_object is None:
                    raise ArchiveError("Cannot read wp-includes/version.php.")
                version_file = file_object.read(128 * 1024 + 1)
                match = VERSION_PATTERN.search(
                    version_file.decode("utf-8", errors="replace")
                )
                if match is None or match.group(1) != expected_version:
                    raise ArchiveError("WordPress version changed during restore.")
                version_found = True

            root_prefix = expected_root + "/"
            if not name.startswith(root_prefix):
                continue
            relative_to_root = name[len(root_prefix) :]
            if not relative_to_root.startswith("wp-content/"):
                continue
            relative_path = relative_to_root[len("wp-content/") :]
            if not is_selected_path(relative_to_root):
                continue
            for selected in RESTORE_PATHS:
                if relative_to_root == selected or relative_to_root.startswith(
                    selected + "/"
                ):
                    found_directories.add(selected)

            if member.issym() or member.islnk() or not (
                member.isdir() or member.isfile()
            ):
                raise ArchiveError(
                    f"Refusing a link or special file in WordPress content: {name}"
                )

            if relative_path in extracted_paths:
                raise ArchiveError(f"Archive contains a duplicate path: {name}")
            extracted_paths.add(relative_path)

            if member.isdir():
                found_directories.add(relative_to_root)
                target = destination.joinpath(*PurePosixPath(relative_path).parts)
                target.mkdir(parents=True, exist_ok=True)
                target.chmod(0o755)
                continue

            file_object = archive.extractfile(member)
            if file_object is None:
                raise ArchiveError(f"Cannot read archive file: {name}")
            target = destination.joinpath(*PurePosixPath(relative_path).parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            mode = member.mode & 0o777
            if mode == 0:
                mode = 0o644
            with target.open("xb") as output:
                shutil.copyfileobj(file_object, output, length=1024 * 1024)
            target.chmod((mode & 0o755) | 0o600)

    if not version_found:
        raise ArchiveError("The expected WordPress version file is missing.")
    missing_directories = required_directories - found_directories
    if missing_directories:
        missing = ", ".join(sorted(missing_directories))
        raise ArchiveError(f"The home archive is missing required directories: {missing}")


def database_member(archive: tarfile.TarFile) -> tuple[tarfile.TarInfo, BinaryIO]:
    candidates = [
        member
        for member in archive.getmembers()
        if member.isfile() and member.name.lower().endswith(".gz")
    ]
    if len(candidates) != 1:
        raise ArchiveError(
            "The database archive must contain exactly one gzipped SQL dump."
        )
    member = candidates[0]
    extracted = archive.extractfile(member)
    if extracted is None:
        raise ArchiveError("Cannot read the gzipped SQL dump.")
    return member, extracted


def inspect_database(archive_path: str) -> tuple[str, str, str]:
    databases: set[str] = set()
    used_databases: set[str] = set()
    table_prefixes: Counter[str] = Counter()

    with open_tar(archive_path, "r:*") as archive:
        member, compressed_stream = database_member(archive)
        try:
            sql_stream = gzip.GzipFile(fileobj=compressed_stream)
            with io.TextIOWrapper(sql_stream, encoding="utf-8", errors="replace") as sql:
                for line in sql:
                    for match in CREATE_DATABASE_PATTERN.finditer(line):
                        databases.add(match.group(1))
                    for match in USE_DATABASE_PATTERN.finditer(line):
                        used_databases.add(match.group(1))
                    for match in CREATE_TABLE_PATTERN.finditer(line):
                        table_name = match.group(1)
                        for suffix in CORE_TABLE_SUFFIXES:
                            if table_name.endswith(suffix):
                                table_prefixes[table_name[: -len(suffix)]] += 1
        except (OSError, EOFError, gzip.BadGzipFile) as error:
            raise ArchiveError(f"The SQL dump is not valid gzip data: {error}") from error

    names = databases | used_databases
    if len(names) != 1:
        raise ArchiveError(
            "The SQL dump must refer to exactly one database with a safe name."
        )
    database_name = next(iter(names))
    if not SAFE_IDENTIFIER_PATTERN.fullmatch(database_name):
        raise ArchiveError("The SQL dump contains an unsafe database name.")
    if table_prefixes:
        table_prefix, count = table_prefixes.most_common(1)[0]
        if count < 2 or not SAFE_IDENTIFIER_PATTERN.fullmatch(table_prefix):
            raise ArchiveError("Cannot safely detect the WordPress table prefix.")
    else:
        raise ArchiveError("Cannot detect the WordPress table prefix in the SQL dump.")
    return member.name, database_name, table_prefix


def stream_database(archive_path: str, member_name: str) -> None:
    with open_tar(archive_path, "r:*") as archive:
        matching = [member for member in archive.getmembers() if member.name == member_name]
        if len(matching) != 1 or not matching[0].isfile():
            raise ArchiveError("The selected SQL dump member is missing.")
        compressed_stream = archive.extractfile(matching[0])
        if compressed_stream is None:
            raise ArchiveError("Cannot read the selected SQL dump.")
        with gzip.GzipFile(fileobj=compressed_stream) as sql:
            shutil.copyfileobj(sql, sys.stdout.buffer, length=1024 * 1024)


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    home_info = subparsers.add_parser("home-info")
    home_info.add_argument("archive")

    extract = subparsers.add_parser("extract-home")
    extract.add_argument("archive")
    extract.add_argument("destination")
    extract.add_argument("version")
    extract.add_argument("root")

    database_info = subparsers.add_parser("database-info")
    database_info.add_argument("archive")

    stream = subparsers.add_parser("stream-database")
    stream.add_argument("archive")
    stream.add_argument("member")

    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "home-info":
            root, version = find_home_root(arguments.archive)
            print(f"{version}\t{root}")
        elif arguments.command == "extract-home":
            extract_home(
                arguments.archive,
                arguments.destination,
                arguments.version,
                arguments.root,
            )
        elif arguments.command == "database-info":
            member, database_name, table_prefix = inspect_database(arguments.archive)
            print(f"{member}\t{database_name}\t{table_prefix}")
        elif arguments.command == "stream-database":
            stream_database(arguments.archive, arguments.member)
        return 0
    except (ArchiveError, OSError, tarfile.TarError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
