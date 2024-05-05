#!/usr/bin/env node

// Invoke with "pnpm --silent" to suppress additional output.

import minimist from "minimist";
import { current, nextSnapshot, nextRelease } from "./version-main.mjs";

const cliArguments = process.argv.slice(2);

const argv = minimist(cliArguments, {
  boolean: ["help", "snapshot"],
  alias: {
    "help": ["h", "?"],
    "snapshot": ["s"],
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
  snapshot = false,
  "_": extraArgs,
} = argv;

if (help) {
  console.log(`Show (next) version information

Usage:

  version [--help|-h|-?] [--snapshot|-s] [major|minor|patch]

Examples:

  version --snapshot patch
  version minor
  version

Hint:

  If used via pnpm, invoke with "pnpm --silent" to suppress additional output.
`);
  process.exit(0);
}

(async () => {
  if (extraArgs.length === 0) {
    console.log(await current());
    return;
  }
  const [release] = extraArgs;
  if (snapshot) {
    console.log(await nextSnapshot(release));
  } else {
    console.log(await nextRelease(release));
  }
})();
