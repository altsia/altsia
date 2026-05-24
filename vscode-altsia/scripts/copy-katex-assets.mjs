import {
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  rmSync,
} from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDir, "..");

const katexDistDir = resolve(projectRoot, "node_modules", "katex", "dist");
const outputDir = resolve(projectRoot, "media", "katex");
const katexFontsDir = resolve(katexDistDir, "fonts");
const outputFontsDir = resolve(outputDir, "fonts");

if (!existsSync(katexDistDir)) {
  throw new Error("KaTeX dist directory not found. Run npm install first.");
}

mkdirSync(outputDir, { recursive: true });
mkdirSync(outputFontsDir, { recursive: true });

cpSync(resolve(katexDistDir, "katex.css"), resolve(outputDir, "katex.css"));
for (const fileName of readdirSync(outputFontsDir)) {
  rmSync(resolve(outputFontsDir, fileName), { force: true });
}

const copiedFonts = [];
for (const fileName of readdirSync(katexFontsDir)) {
  if (!fileName.endsWith(".woff2")) {
    continue;
  }
  cpSync(resolve(katexFontsDir, fileName), resolve(outputFontsDir, fileName));
  copiedFonts.push(fileName);
}

console.log(`Copied KaTeX CSS and ${copiedFonts.length} woff2 fonts to media/katex`);
