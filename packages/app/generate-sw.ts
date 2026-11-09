import { createHash } from "node:crypto"
import { readFile } from "node:fs/promises"
import { resolve } from "node:path"
import { generateSW } from "../../node_modules/.bun/workbox-build@7.4.1+e0299c3a2094a655/node_modules/workbox-build"
import { onDemandAsset } from "./vite.pwa.ts"

const directory = resolve(import.meta.dir, "dist")

const result = await generateSW({
  sourcemap: false,
  globDirectory: directory,
  swDest: resolve(directory, "sw.js"),
  clientsClaim: false,
  skipWaiting: false,
  inlineWorkboxRuntime: true,
  navigateFallback: "/index.html",
  navigateFallbackDenylist: [/^\/(?:api|auth)(?:\/|$)/, /^\/(?:_assets|assets)(?:\/|$)/],
  globPatterns: ["**/*"],
  globIgnores: ["**/*.map", "_headers", "_redirects"],
  maximumFileSizeToCacheInBytes: Number.MAX_SAFE_INTEGER,
  manifestTransforms: [
    async (entries) => ({
      manifest: await Promise.all(
        entries
          .filter((entry) => !onDemandAsset(entry.url))
          .map(async (entry) => ({
            ...entry,
            integrity: `sha256-${createHash("sha256")
              .update(await readFile(resolve(directory, entry.url)))
              .digest("base64")}`,
          })),
      ),
      warnings: [],
    }),
  ],
})

console.log("[Termux PWA] Service worker generated:", result)
