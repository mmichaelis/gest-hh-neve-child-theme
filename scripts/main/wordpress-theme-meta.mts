import data from "../../wordpress-theme-meta.json" with { type: "json" };
import { about } from "./about.mts";

export const wordpressThemeMeta = async (version = "") => {
  if (!version) {
    const packageVersion = await about(["version"]);
    if (typeof packageVersion !== "string") {
      throw new TypeError(
        "The package version in package.json must be a string.",
      );
    }
    version = packageVersion;
  }
  return {
    ...data,
    Version: version,
  };
};

export const wordpressThemeMetaString = async (version = "") => {
  const meta = await wordpressThemeMeta(version);
  const maxKeyLength = Math.max(...Object.keys(meta).map((key) => key.length));
  const padKey = (key: string, additional = 1) =>
    key.padEnd(maxKeyLength + additional);
  return Object.entries(meta)
    .map(([key, value]) => `${padKey(`${key}:`)} ${value}`)
    .join("\n");
};
