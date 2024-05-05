import readPackageJson from "read-package-json";

const packageJson = "package.json";

const read = () => {
  return new Promise((resolve, reject) => {
    readPackageJson(packageJson, console.error, false, (err, data) => {
      if (err) {
        reject(err);
      }
      resolve(data);
    });
  });
};

export const about = async (path) => {
  let currentData = await read();

  path.forEach((extraArg) => {
    if (!currentData[extraArg]) {
      console.error(`Path "${extraArg}" not found in package.json.`);
      process.exit(1);
    }
    currentData = currentData[extraArg];
  });

  return currentData;
}
