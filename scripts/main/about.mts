import packageJson from "@npmcli/package-json";

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

const readPackageJson = async (): Promise<unknown> => {
  const { content } = await packageJson.load(".");
  return content;
};

export const about = async (
  nodePath: Array<string | number>,
): Promise<unknown> => {
  let currentData = await readPackageJson();
  const pathFound: string[] = [];

  nodePath.forEach((nodePathElement) => {
    const key = String(nodePathElement);
    if (!isRecord(currentData) || !currentData[key]) {
      let message;
      if (pathFound.length > 0) {
        message = `Path "${key}" not found at ${pathFound.join(".")} in package.json.`;
      } else {
        message = `Path "${key}" not found in package.json.`;
      }
      throw new Error(message);
    }
    pathFound.push(key);
    currentData = currentData[key];
  });

  return currentData;
};
