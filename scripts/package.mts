#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import { unzipSync, zipSync } from "fflate";
import { build } from "./main/build.mts";

const cliArguments = process.argv.slice(2);
if (cliArguments[0] === "--") {
  cliArguments.shift();
}

if (cliArguments.length > 1 || cliArguments[0] === "") {
  console.error("Usage: package [build-folder]");
  process.exit(2);
}

const buildFolderPath = cliArguments[0] ?? "./build";

const collectFiles = async (
  themeDirectory: string,
  currentDirectory: string,
): Promise<Record<string, Uint8Array>> => {
  const files: Record<string, Uint8Array> = {};
  const entries = await fs.readdir(currentDirectory, { withFileTypes: true });

  entries.sort((left, right) =>
    left.name < right.name ? -1 : left.name > right.name ? 1 : 0,
  );

  for (const entry of entries) {
    const entryPath = path.join(currentDirectory, entry.name);
    if (entry.isDirectory()) {
      Object.assign(files, await collectFiles(themeDirectory, entryPath));
    } else if (entry.isFile()) {
      const relativePath = path
        .relative(themeDirectory, entryPath)
        .split(path.sep)
        .join("/");
      files[relativePath] = await fs.readFile(entryPath);
    } else {
      throw new Error(`Unsupported file type in theme directory: ${entryPath}`);
    }
  }

  return files;
};

const createArchive = (
  themeName: string,
  files: Record<string, Uint8Array>,
) => {
  const archiveFiles = Object.fromEntries(
    Object.entries(files).map(([filePath, contents]) => [
      path.posix.join(themeName, filePath),
      contents,
    ]),
  );
  const archive = zipSync(archiveFiles, { level: 6 });
  const archivePaths = Object.keys(unzipSync(archive));
  const themePrefix = `${themeName}/`;
  const unexpectedPath = archivePaths.find(
    (filePath) => !filePath.startsWith(themePrefix),
  );

  if (unexpectedPath) {
    throw new Error(`Unexpected path in theme archive: ${unexpectedPath}`);
  }

  for (const requiredFile of ["functions.php", "style.css"]) {
    if (!archivePaths.includes(`${themePrefix}${requiredFile}`)) {
      throw new Error(`Theme archive is missing ${requiredFile}.`);
    }
  }

  return archive;
};

const packageTheme = async () => {
  const themeDirectory = await build("./src", buildFolderPath);
  const themeName = path.basename(themeDirectory);
  const files = await collectFiles(themeDirectory, themeDirectory);
  const archive = createArchive(themeName, files);
  const archivePath = path.join(
    path.dirname(themeDirectory),
    `${themeName}.zip`,
  );

  await fs.writeFile(archivePath, archive);
  console.log(`Created theme archive: ${archivePath}`);
};

packageTheme().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
