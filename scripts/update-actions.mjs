import { promises as fs } from "fs";
import path from "path";
import fetch from "node-fetch";

const workflowsDir = path.resolve(".github/workflows");

async function getLatestVersion(action) {
  const response = await fetch(
    `https://api.github.com/repos/${action}/releases/latest`,
  );
  const data = await response.json();
  // Fail, if `tag_name` is not present.
  if (!data["tag_name"]) {
    throw new Error(
      `Failed to get the latest version of ${action}. Response: ${JSON.stringify(
        data,
      )}`,
    );
  }
  return data["tag_name"];
}

async function getLatestMajorVersion(action) {
  const latestVersion = await getLatestVersion(action);
  return latestVersion.split(".")[0];
}

async function getLatestMajorVersions(actions) {
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
function getUsedActions(content) {
  const actions = new Map();
  const pattern = /uses: ([^@\n]+)@([^ \n]+)/g;
  let match;
  while ((match = pattern.exec(content))) {
    const [, action, version] = match;
    actions.set(action, version);
  }
  return actions;
}

async function updateWorkflowFile(filePath) {
  console.log(`Updating ${filePath}`);

  const content = await fs.readFile(filePath, "utf8");
  const usedActions = getUsedActions(content);
  const latestMajorVersions = await getLatestMajorVersions(usedActions);
  const updatedContent = Array.from(usedActions).reduce(
    (content, [action, version]) => {
      const latestMajorVersion = latestMajorVersions.get(action);
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

async function updateAllWorkflows() {
  const files = await fs.readdir(workflowsDir);
  for (const file of files) {
    const filePath = path.join(workflowsDir, file);
    await updateWorkflowFile(filePath);
  }
}

updateAllWorkflows().catch(console.error);
