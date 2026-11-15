import globals from "globals";
import pluginJs from "@eslint/js";
import pluginPrettierRecommended from "eslint-plugin-prettier/recommended";
import pluginYml from "eslint-plugin-yml";

export default [
  {
    ignores: [
      ".idea/*",
      "pnpm-lock.yaml",
      "node_modules/*",
      "build/*",
      ".local-wordpress/**",
    ],
  },
  {
    languageOptions: { globals: globals.node },
  },
  pluginJs.configs.recommended,
  pluginPrettierRecommended,
  ...pluginYml.configs["flat/recommended"],
];
