import { createRequire } from "module";
import { about } from "./about-main.mjs";

const require = createRequire(import.meta.url);
const data = require("../wordpress-theme-meta.json");

export const wordpressThemeMeta = async (version = "") => {
  if (!version) {
    version = await about(["version"]);
  }
  return {
    ...data,
    "Version": version,
  };
}

export const wordpressThemeMetaString = async (version = "") => {
  const meta = await wordpressThemeMeta(version);
  const maxKeyLength = Math.max(...Object.keys(meta).map((key) => key.length));
  const padKey = (key, additional = 1) => key.padEnd(maxKeyLength + additional);
  return Object.entries(meta)
    .map(([key, value]) => `${padKey(`${key}:`)} ${value}`)
    .join("\n");
}
