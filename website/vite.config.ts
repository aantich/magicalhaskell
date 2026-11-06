import vinext from "vinext";
import { defineConfig } from "vite";
import { sites } from "./scripts/vite/sites-vite-plugin";

// GitHub Pages serves the exported files; no Worker runtime is needed.
export default defineConfig({
  plugins: [vinext(), sites({ mockAuth: false })],
  server: {
    host: "127.0.0.1",
    ...(process.env.CODEX_SANDBOX === "seatbelt"
      ? { watch: { useFsEvents: false, usePolling: true } }
      : {}),
  },
});
