#!/usr/bin/env node

// Invoke with "pnpm --silent" to suppress additional output.

import minimist from "minimist";
import { build } from "./main/build.mjs";

const cliArguments = process.argv.slice(2);

const argv = minimist(cliArguments, {
  boolean: ["help", "silent"],
  alias: {
    help: ["h", "?"],
    silent: ["s"],
  },
  unknown: (unknownArg) => {
    // Don't fail for non-options.
    if (unknownArg.startsWith("-")) {
      console.error(`Unknown argument ${unknownArg} passed to "version"!"`);
      process.exit(1);
    }
  },
});

const { help = false, silent = false, _: extraArgs } = argv;

if (help || extraArgs.length !== 2) {
  const isParameterError = !help && extraArgs.length !== 2;
  if (isParameterError) {
    console.error(`Missing required source and/or target folder.`);
  }

  console.log(`Build the theme.

Usage:

  build [--help|-h|-?] [--silent|-s] <src-folder> <target-folder>

Examples:

  build ./src ./build
`);
  process.exit(isParameterError ? 1 : 0);
}

(async () => {
  const [srcFolder, targetFolder] = extraArgs;
  const path = await build(srcFolder, targetFolder);
  if (!silent) {
    console.log(path);
  }
})();
