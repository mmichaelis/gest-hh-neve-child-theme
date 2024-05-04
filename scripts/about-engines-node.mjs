#!/usr/bin/env node

// Invoke with "pnpm --silent" to suppress additional output.

import readJson from "read-package-json";

const packageJson = "package.json";

readJson(packageJson, console.error, false, (er, data) => {
  if (er) {
    console.error(`Error reading ${packageJson}: ${er}`);
    process.exit(1);
  }
  console.log(data.engines.node);
});
