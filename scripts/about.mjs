#!/usr/bin/env node

// Invoke with "pnpm --silent" to suppress additional output.

import minimist from "minimist";
import readJson from "read-package-json";

const packageJson = "package.json";
const cliArguments = process.argv.slice(2);

const argv = minimist(cliArguments, {
  boolean: ["help"],
  alias: {
    "help": ["h", "?"],
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

if (help || extraArgs.length === 0) {
  const isRequiredArgsMissing = !help && extraArgs.length === 0;
  if (isRequiredArgsMissing) {
    console.error(`Missing required path to select from package.json.`);
  }

  console.log(`Show information from package.json

Usage:

  about [--help|-h|-?] node1 node2

Example:

  about engines node

Hint:

  If used via pnpm, invoke with "pnpm --silent" to suppress additional output.
`);
  process.exit(isRequiredArgsMissing ? 1 : 0);
}

readJson(packageJson, console.error, false, (err, data) => {
  if (err) {
    console.error(`Error reading ${packageJson}: ${err}`);
    process.exit(1);
  }

  let currentData = data;
  extraArgs.forEach((extraArg) => {
    if (!currentData[extraArg]) {
      console.error(`Path "${extraArg}" not found in package.json.`);
      process.exit(1);
    }
    currentData = currentData[extraArg];
  });

  console.log(currentData);
});
