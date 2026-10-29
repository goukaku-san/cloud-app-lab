// public/icons/icon.svg から PNG アイコンを生成する（環境同梱の Playwright/Chromium を使用。外部通信なし）。
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const svg = fs.readFileSync(path.join(root, "public/icons/icon.svg"), "utf8");
const sizes = [180, 192, 512];

const browser = await chromium.launch();
try {
  for (const size of sizes) {
    const page = await browser.newPage({ viewport: { width: size, height: size }, deviceScaleFactor: 1 });
    await page.setContent(
      `<!doctype html><html><body style="margin:0;background:transparent">${svg.replace(/width="512" height="512"/, `width="${size}" height="${size}"`)}</body></html>`,
    );
    const out = path.join(root, `public/icons/icon-${size}.png`);
    await page.screenshot({ path: out, omitBackground: true, clip: { x: 0, y: 0, width: size, height: size } });
    console.log("wrote", out);
    await page.close();
  }
} finally {
  await browser.close();
}
