import fs from "node:fs/promises";
import path from "node:path";
import fetch from "node-fetch";

const workflowsDir = path.resolve(".github/workflows");

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

async function getLatestVersion(action: string): Promise<string> {
  const response = await fetch(
    `https://api.github.com/repos/${action}/releases/latest`,
  );
  const data: unknown = await response.json();
  // Fail, if `tag_name` is not present.
  if (!isRecord(data) || typeof data.tag_name !== "string") {
    throw new Error(
      `Failed to get the latest version of ${action}. Response: ${JSON.stringify(
        data,
      )}`,
    );
  }
  return data["tag_name"];
}

async function getLatestMajorVersion(action: string): Promise<string> {
  const latestVersion = await getLatestVersion(action);
  return latestVersion.split(".")[0];
}

async function getLatestMajorVersions(
  actions: Map<string, string>,
): Promise<Map<string, string>> {
  const versions = new Map();
  for (const action of actions.keys()) {
    const latestVersion = await getLatestMajorVersion(action);
    versions.set(action, latestVersion);
  }
  return versions;
}

/**
 * Get a map of used actions and their versions.
 *
 * @param content {string} The content of a workflow file.
 * @returns {Map<string, string>} A map of used actions and their versions.
 */
function getUsedActions(content: string): Map<string, string> {
  const actions = new Map();
  const pattern = /uses: ([^@\n]+)@([^ \n]+)/g;
  let match;
  while ((match = pattern.exec(content))) {
    const [, action, version] = match;
    actions.set(action, version);
  }
  return actions;
}

async function updateWorkflowFile(filePath: string): Promise<void> {
  console.log(`Updating ${filePath}`);

  const content = await fs.readFile(filePath, "utf8");
  const usedActions = getUsedActions(content);
  const latestMajorVersions = await getLatestMajorVersions(usedActions);
  const updatedContent = Array.from(usedActions).reduce(
    (content, [action, version]) => {
      const latestMajorVersion = latestMajorVersions.get(action);
      if (!latestMajorVersion) {
        throw new Error(`Failed to determine the latest version of ${action}.`);
      }
      if (latestMajorVersion === version) {
        console.log(`No update needed for ${action} (${version})`);
        return content;
      }
      console.log(`Updating ${action} (${version}) to ${latestMajorVersion}`);
      const updatedAction = `${action}@${latestMajorVersion}`;
      return content.replace(`${action}@${version}`, updatedAction);
    },
    content,
  );
  await fs.writeFile(filePath, updatedContent, "utf8");
}

async function updateAllWorkflows(): Promise<void> {
  const files = await fs.readdir(workflowsDir);
  for (const file of files) {
    const filePath = path.join(workflowsDir, file);
    await updateWorkflowFile(filePath);
  }
}

updateAllWorkflows().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
