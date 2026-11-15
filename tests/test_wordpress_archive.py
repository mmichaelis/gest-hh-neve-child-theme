import gzip
import io
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "sh"))
import wordpress_archive


class WordPressArchiveTests(unittest.TestCase):
    def create_home_archive(self, path, include_link=False):
        entries = {
            "/home/www/wordpress/wp-includes/version.php": (
                b"<?php $wp_version = '7.1.4';"
            ),
            "/home/www/wordpress/wp-content/plugins/sample/main.php": b"<?php",
            "/home/www/wordpress/wp-content/uploads/2024/image.jpg": b"image",
            "/home/www/wordpress/wp-content/themes/neve/style.css": b"theme",
            "/home/www/wordpress/wp-content/themes/gest-hh-neve-child/style.css": (
                b"production child theme"
            ),
        }
        directories = (
            "/home/www/wordpress/wp-content/plugins",
            "/home/www/wordpress/wp-content/uploads",
            "/home/www/wordpress/wp-content/themes/neve",
            "/home/www/wordpress/wp-content/mu-plugins",
        )
        with tarfile.open(path, "w:gz") as archive:
            for directory in directories:
                member = tarfile.TarInfo(directory)
                member.type = tarfile.DIRTYPE
                archive.addfile(member)
            for name, contents in entries.items():
                member = tarfile.TarInfo(name)
                member.size = len(contents)
                archive.addfile(member, io.BytesIO(contents))
            if include_link:
                member = tarfile.TarInfo(
                    "/home/www/wordpress/wp-content/plugins/sample/outside"
                )
                member.type = tarfile.SYMTYPE
                member.linkname = "/tmp/outside"
                archive.addfile(member)

    def create_database_archive(self, path):
        sql = b"""CREATE DATABASE /*!32312 IF NOT EXISTS*/ `localdb`;
USE `localdb`;
CREATE TABLE `gowp_options` (`option_id` bigint);
CREATE TABLE `gowp_posts` (`ID` bigint);
CREATE TABLE `gowp_users` (`ID` bigint);
"""
        compressed = gzip.compress(sql)
        with tarfile.open(path, "w") as archive:
            member = tarfile.TarInfo("database.sql.gz")
            member.size = len(compressed)
            archive.addfile(member, io.BytesIO(compressed))

    def test_extracts_only_validated_wordpress_content(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary = Path(temporary_directory)
            archive_path = temporary / "home.tar.gz"
            destination = temporary / "restored" / "wp-content"
            self.create_home_archive(archive_path)

            root, version = wordpress_archive.find_home_root(str(archive_path))
            self.assertEqual(root, "home/www/wordpress")
            self.assertEqual(version, "7.1.4")
            wordpress_archive.extract_home(
                str(archive_path), str(destination), version, root
            )

            self.assertEqual(
                (destination / "plugins/sample/main.php").read_bytes(), b"<?php"
            )
            self.assertTrue((destination / "uploads/2024/image.jpg").is_file())
            self.assertTrue((destination / "themes/neve/style.css").is_file())
            self.assertFalse(
                (destination / "themes/gest-hh-neve-child/style.css").exists()
            )

    def test_refuses_links_in_restored_content(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary = Path(temporary_directory)
            archive_path = temporary / "home.tar.gz"
            destination = temporary / "restored" / "wp-content"
            self.create_home_archive(archive_path, include_link=True)
            root, version = wordpress_archive.find_home_root(str(archive_path))

            with self.assertRaises(wordpress_archive.ArchiveError):
                wordpress_archive.extract_home(
                    str(archive_path), str(destination), version, root
                )

    def test_detects_database_name_and_wordpress_prefix(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            archive_path = Path(temporary_directory) / "database.tar"
            self.create_database_archive(archive_path)

            member, database_name, table_prefix = (
                wordpress_archive.inspect_database(str(archive_path))
            )

            self.assertEqual(member, "database.sql.gz")
            self.assertEqual(database_name, "localdb")
            self.assertEqual(table_prefix, "gowp_")

    def test_rejects_archive_path_traversal(self):
        with self.assertRaises(wordpress_archive.ArchiveError):
            wordpress_archive.normalized_name("home/www/wordpress/../outside")


if __name__ == "__main__":
    unittest.main()
