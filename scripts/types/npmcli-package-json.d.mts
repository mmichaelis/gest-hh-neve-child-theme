declare module "@npmcli/package-json" {
  const packageJson: {
    load(path: string): Promise<{ content: unknown }>;
  };

  export default packageJson;
}
