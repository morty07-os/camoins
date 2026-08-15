import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { viteSingleFile } from "vite-plugin-singlefile";
import path from "path";

// Configuration dédiée au bundle "artifact" : produit un index.html autonome.
export default defineConfig({
  plugins: [react(), viteSingleFile()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src")
    }
  },
  build: {
    outDir: "dist-bundle",
    sourcemap: false,
    cssCodeSplit: false,
    assetsInlineLimit: 100000000
  }
});
