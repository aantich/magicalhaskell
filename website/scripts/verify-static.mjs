import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import { resolve, sep } from "node:path";

const root = resolve("dist/client");
const html = await readFile(resolve(root, "index.html"), "utf8");
assert.match(html, /Magical/);
assert.match(html, /https:\/\/magicalhaskell\.com/);
assert.match(html, /<link[^>]+rel="canonical"/);
assert.match(html, /application\/ld\+json/);
assert.equal((await readFile(resolve(root, "CNAME"), "utf8")).trim(), "magicalhaskell.com");
await access(resolve(root, ".nojekyll"));

// Check that the exported document's local scripts, styles, and images exist.
const references = new Set();
for (const match of html.matchAll(/<(?:script|link|img)\b[^>]*\b(?:src|href)="([^"]+)"/g)) {
  const url = new URL(match[1].replaceAll("&amp;", "&"), "https://magicalhaskell.com/");
  if (url.origin !== "https://magicalhaskell.com" || url.pathname === "/") continue;
  references.add(decodeURIComponent(url.pathname));
}
assert.ok(references.size > 0, "Export must contain local assets");
for (const reference of references) {
  const path = resolve(root, `.${reference}`);
  assert.ok(path.startsWith(root + sep), "Asset path must remain inside the export");
  await access(path);
}
console.log(`Static export verified: index.html, domain metadata, and ${references.size} local assets.`);
