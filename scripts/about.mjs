#!/usr/bin/env node

// Invoke with "pnpm --silent" to suppress additional output.

import minimist from "minimist";
import { about } from "./about-main.mjs";

const cliArguments = process.argv.slice(2);

const argv = minimist(cliArguments, {
  boolean: ["help"],
  alias: {
    "help": ["h", "?"],
  },
  unknown: (unknownArg) => {
    // Don't fail for non-options.
    if (unknownArg.startsWith("-")) {
      console.error(`Unknown argument ${unknownArg} passed to "about"!"`);
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

(async () => {
  const data = await about(extraArgs);
  console.log(data);
})();
