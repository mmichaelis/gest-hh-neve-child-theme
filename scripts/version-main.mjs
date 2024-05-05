import { about } from "./about-main.mjs";
import semver from "semver";

export const current = async () => {
  return await about(["version"]);
};

const next = async (release, options, identifier, identifierBase) => {
  const currentVersion = await current();
  return semver.inc(currentVersion, release, options, identifier, identifierBase);
};

/**
 * Returns the next release version.
 *
 * @param {"major"|"minor"|"patch"} release
 * @returns {Promise<string>} next release version
 */
export const nextRelease = async (release) => {
  return await next(release);
};

/**
 * Returns the next snapshot version, given we just released a version.
 *
 * @param release {"major"|"minor"|"patch"} release
 * @returns {Promise<string>} next snapshot release version
 */
export const nextSnapshot = async (release) => {
  const nextReleaseVersion = await next(release);
  return semver.inc(nextReleaseVersion, "prerelease", "alpha");
};
