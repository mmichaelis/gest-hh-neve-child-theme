import packageJson from "@npmcli/package-json";

const readPackageJson = async () => {
  const { content } = await packageJson.load(".");
  return content;
};

/**
 * Reads a given node from `package.json`.
 *
 * @param {string[]} nodePath
 * @returns data read
 * @throws Error if path on package.json cannot be found
 */
export const about = async (nodePath) => {
  let currentData = await readPackageJson();
  const pathFound = [];

  nodePath.forEach((nodePathElement) => {
    if (!currentData[nodePathElement]) {
      let message;
      if (pathFound.length > 0) {
        message = `Path "${nodePathElement}" not found at ${pathFound.join(".")} in package.json.`;
      } else {
        message = `Path "${nodePathElement}" not found in package.json.`;
      }
      throw new Error(message);
    }
    pathFound.push(nodePathElement);
    currentData = currentData[nodePathElement];
  });

  return currentData;
};
