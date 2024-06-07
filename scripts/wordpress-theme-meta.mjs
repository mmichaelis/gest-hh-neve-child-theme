#!/usr/bin/env node

// Invoke with "pnpm --silent" to suppress additional output.

import minimist from "minimist";
import { wordpressThemeMetaString } from "./wordpress-theme-meta-main.mjs";

const cliArguments = process.argv.slice(2);

const argv = minimist(cliArguments, {
  boolean: ["help"],
  string: ["version"],
  alias: {
    help: ["h", "?"],
    version: ["v"],
  },
  unknown: (unknownArg) => {
    console.error(
      `Unknown argument ${unknownArg} passed to "wordpress-theme-meta"!"`,
    );
    process.exit(1);
  },
});

const { help = false, version = "" } = argv;

if (help) {
  console.log(`Show WordPress Theme Meta Information

Usage:

  wordpress-theme-meta [--help|-h|-?] [--version|-v <version>]

Examples:

  wordpress-theme-meta
  wordpress-theme-meta --version 1.0.0

Hint:

  If used via pnpm, invoke with "pnpm --silent" to suppress additional output.
`);
  process.exit(0);
}

(async () => {
  const meta = await wordpressThemeMetaString(version);
  console.log(meta);
})();
