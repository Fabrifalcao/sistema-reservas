import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    // Lee los "paths" de tsconfig.json, así los tests entienden el alias @/
    tsconfigPaths: true,
  },
  test: {
    include: ["src/**/*.test.ts"],
  },
});
