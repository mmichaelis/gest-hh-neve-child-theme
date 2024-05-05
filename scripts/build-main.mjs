import fs from "node:fs/promises";
import path from "node:path";
import { wordpressThemeMetaString } from "./wordpress-theme-meta-main.mjs";

const defaultSourceFolderPath = "./src";
const defaultBuildFolderPath = "./build";

export const build = async (sourceFolderPath = defaultSourceFolderPath,
                            buildFolderPath = defaultBuildFolderPath) => {
  const absSource = path.resolve(sourceFolderPath);
  const absTarget = path.resolve(buildFolderPath);

  await fs.rm(absTarget, { recursive: true, force: true });
  await fs.mkdir(absTarget);

  await fs.cp(absSource, absTarget, { recursive: true });
  const styleMainContent = await fs.readFile(`${absSource}/style.css`, "utf-8");
  const wordpressMeta = await wordpressThemeMetaString();
  const buildStyleContent = `/*\n${wordpressMeta}\n*/\n\n${styleMainContent}`;
  await fs.writeFile(`${absTarget}/style.css`, buildStyleContent);

  return absTarget;
}
