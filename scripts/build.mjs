#!/usr/bin/env node

// Invoke with "pnpm --silent" to suppress additional output.

import minimist from "minimist";
import { current, nextSnapshot, nextRelease } from "./version-main.mjs";
import { build } from "./build-main.mjs";

const cliArguments = process.argv.slice(2);

const argv = minimist(cliArguments, {
  boolean: ["help"],
  alias: {
    "help": ["h", "?"]
  },
  unknown: (unknownArg) => {
    // Don't fail for non-options.
    if (unknownArg.startsWith("-")) {
      console.error(`Unknown argument ${unknownArg} passed to "version"!"`);
      process.exit(1);
    }
  },
});

const {
  help = false,
  "_": extraArgs,
} = argv;

if (help || extraArgs.length !== 2) {
  const isParameterError = !help && extraArgs.length !== 2;
  if (isParameterError) {
    console.error(`Missing required source and/or target folder.`);
  }

  console.log(`Build the theme.

Usage:

  build [--help|-h|-?] <src-folder> <target-folder>

Examples:

  build ./src ./build
`);
  process.exit(isParameterError ? 1 : 0);
}

(async () => {
  const [srcFolder, targetFolder] = extraArgs;
  console.log(await build(srcFolder, targetFolder));
})();
