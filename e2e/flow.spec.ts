import { expect, test, type BrowserContext, type Page } from "@playwright/test";

// 設計書 14 章「必須受入テスト」に対応する E2E。番号はその項目に対応する。
// スマホ幅（375×667）、Chromium。実機（iOS Safari / Android Chrome）は未検証。
test.describe.configure({ mode: "serial" });

const shot = (page: Page, name: string) => page.screenshot({ path: `docs/screenshots/${name}.png`, fullPage: true, animations: "disabled" });

test.describe("縦切り: 鏡の部屋 → 出発 → 帰還 → 変化", () => {
  let context: BrowserContext;
  let page: Page;
  const externalRequests: string[] = [];

  test.beforeAll(async ({ browser, baseURL }) => {
    context = await browser.newContext({
      baseURL,
      viewport: { width: 375, height: 667 },
      isMobile: true,
      hasTouch: true,
      serviceWorkers: "allow",
    });
    context.on("request", (req) => {
      if (!req.url().startsWith(baseURL ?? "")) externalRequests.push(req.url());
    });
    page = await context.newPage();
  });

  test.afterAll(async () => {
    await context.close();
  });

  test("14-1 / 14-7 ニックネームなしで開始し、3 分以内に部屋とプレビューを体験できる", async () => {
    const t0 = Date.now();
    await page.goto("/");
    await expect(page).toHaveURL(/\/intro\/$/);
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("受験生の鏡");
    await shot(page, "01-intro");
    await page.getByRole("button", { name: "はじめる" }).click();

    await expect(page).toHaveURL(/\/avatar\/$/);
    await page.getByRole("radio", { name: "おだんご" }).click();
    await page.getByRole("radio", { name: "わかくさ" }).click();
    await page.getByRole("radio", { name: "ねこ" }).click();
    await shot(page, "02-avatar");
    await page.getByRole("button", { name: "この姿にする" }).click();

    await expect(page).toHaveURL(/\/room\/$/);
    const dialog = page.getByTestId("preview-dialog");
    await expect(dialog).toBeVisible();
    await expect(dialog).toContainText("これはプレビューです");
    await expect(page.getByTestId("room")).toHaveAttribute("data-growth", "0");
    await shot(page, "03-preview");
    await dialog.getByRole("button", { name: "自分の部屋へ" }).click();
    await expect(dialog).toBeHidden();
    await expect(page.getByTestId("room-stage")).toHaveText("静かな部屋");
    await expect(page.getByTestId("today-status")).toHaveText("今日はまだ出発していません。");
    await shot(page, "04-room-stage0");

    // 小型スマホで横スクロールが出ない
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow).toBeLessThanOrEqual(0);
    expect(Date.now() - t0).toBeLessThan(180_000);
  });

  test("14-2 / 14-3 行動を選び、出発し、閉じて（再読込）、帰還すると世界が変わる", async () => {
    await page.getByRole("link", { name: "作戦会議へ" }).click();
    await expect(page).toHaveURL(/\/plan\/$/);
    await expect(page.getByRole("radio")).toHaveCount(4); // 3 案 + 自分で決める
    await page.getByTestId("quest-0").click();
    await page.getByRole("button", { name: "5 分増やす" }).click();
    await shot(page, "05-plan");
    await page.getByTestId("depart").click();

    await expect(page).toHaveURL(/\/journey\/$/);
    await expect(page.getByTestId("journey-quest")).toBeVisible();
    await shot(page, "06-journey");
    // アプリを閉じて開き直す代替: 再読込しても出発中が続く
    await page.reload();
    await expect(page).toHaveURL(/\/journey\/$/);
    await expect(page.getByTestId("journey-quest")).toBeVisible();
    // 出発中に部屋へ直接行っても出発中画面へ戻る
    await page.goto("/room/");
    await expect(page).toHaveURL(/\/journey\/$/);

    await page.getByTestId("return").click();
    await expect(page).toHaveURL(/\/return\/$/);
    await page.getByTestId("report-done").click();
    await page.getByRole("textbox", { name: /ひとこと/ }).fill("公式を1つ覚えた");
    await shot(page, "07-return");
    await page.getByTestId("see-mirror").click();

    await expect(page).toHaveURL(/\/change\/$/);
    await expect(page.getByTestId("before-after").locator("svg")).toHaveCount(2);
    await expect(page.getByTestId("change-report")).toHaveText("やった");
    await expect(page.getByTestId("story-title")).not.toBeEmpty();
    await expect(page.getByTestId("growth-delta")).toHaveText("成長 +2");
    await expect(page.getByTestId("after-stage")).toHaveText("灯りのともる部屋");
    await shot(page, "08-change");
    await page.getByRole("link", { name: "部屋へ戻る" }).click();

    await expect(page).toHaveURL(/\/room\/$/);
    await expect(page.getByTestId("room-stage")).toHaveText("灯りのともる部屋");
    await expect(page.getByTestId("room")).toHaveAttribute("data-growth", "2");
    await expect(page.getByTestId("today-status")).toHaveText("今日は1回、帰還しました。");
    await shot(page, "09-room-stage1");
  });

  test("14-4 「今日は休んだ」「記録しない」でも罰・減点・記録の破壊がない", async () => {
    await page.getByRole("link", { name: "作戦会議へ" }).click();
    await page.getByTestId("quest-2").click();
    await page.getByTestId("depart").click();
    await page.getByTestId("return").click();
    await page.getByTestId("report-rest").click();
    await page.getByTestId("see-mirror").click();
    await expect(page.getByTestId("change-report")).toHaveText("今日は休んだ");
    await expect(page.getByTestId("growth-delta")).toHaveText("成長 +1");
    await expect(page.getByTestId("story-title")).not.toBeEmpty();
    await expect(page.locator("body")).not.toContainText(/罰|減点|サボ|連続/);
    await expect(page.locator("body")).toContainText("ひざ掛け");
    await shot(page, "10-change-rest");
    await page.getByRole("link", { name: "部屋へ戻る" }).click();
    await expect(page.getByTestId("room")).toHaveAttribute("data-growth", "3");
    await expect(page.getByTestId("room-stage")).toHaveText("窓辺に緑");

    // 記録せずに戻る
    await page.getByRole("link", { name: "作戦会議へ" }).click();
    await page.getByTestId("quest-0").click();
    await page.getByTestId("depart").click();
    await page.getByTestId("skip").click();
    await page.getByTestId("skip-confirm").click();
    await expect(page).toHaveURL(/\/room\/$/);
    await expect(page.getByTestId("room")).toHaveAttribute("data-growth", "3");
    await expect(page.getByTestId("room-stage")).toHaveText("窓辺に緑");
  });

  test("14-5 同じ日に何度帰還しても成長は上限で止まり、罰はない", async () => {
    await page.getByRole("link", { name: "作戦会議へ" }).click();
    await page.getByTestId("quest-0").click();
    await page.getByTestId("depart").click();
    await page.getByTestId("return").click();
    await page.getByTestId("report-done").click();
    await page.getByTestId("see-mirror").click();
    await expect(page.getByTestId("growth-delta")).toHaveText("成長 +0");
    await expect(page.getByTestId("capped-note")).toBeVisible();
    await expect(page.getByTestId("story-title")).not.toBeEmpty();
    await expect(page.locator("body")).not.toContainText(/罰|減点|サボ|連続/);
    await shot(page, "11-change-capped");
    await page.getByRole("link", { name: "部屋へ戻る" }).click();
    await expect(page.getByTestId("room")).toHaveAttribute("data-growth", "3");
  });

  test("14-6 オフラインでも部屋が表示され、再起動後も保存されている", async () => {
    await page.reload();
    await page.waitForFunction(() => Boolean(navigator.serviceWorker?.controller), null, { timeout: 15_000 });
    await context.setOffline(true);
    await page.reload();
    await expect(page.getByTestId("room-stage")).toHaveText("窓辺に緑", { timeout: 15_000 });
    await expect(page.getByTestId("room")).toHaveAttribute("data-growth", "3");
    await context.setOffline(false);

    // 再起動の代替: 新しいタブで起動しても同じ状態
    const page2 = await context.newPage();
    await page2.goto("/");
    await expect(page2).toHaveURL(/\/room\/$/);
    await expect(page2.getByTestId("room")).toHaveAttribute("data-growth", "3");
    await page2.close();
  });

  test("14-7 旅の記録は本人に表示され、設定から完全に削除できる", async () => {
    await page.getByRole("link", { name: "旅の記録" }).click();
    await expect(page).toHaveURL(/\/log\/$/);
    await expect(page.getByTestId("log-list").locator("li")).toHaveCount(4);
    await expect(page.getByTestId("log-list")).toContainText("公式を1つ覚えた");
    await expect(page.getByTestId("log-list")).toContainText("記録なし");
    await shot(page, "12-log");
    await page.getByRole("link", { name: "部屋" }).click();

    await page.getByRole("link", { name: "設定" }).click();
    await expect(page).toHaveURL(/\/settings\/$/);
    await page.getByRole("switch", { name: "動きを減らす" }).click();
    await expect(page.locator("html")).toHaveClass(/reduce-motion/);
    await page.getByRole("switch", { name: "文字を大きく" }).click();
    await expect(page.locator("html")).toHaveClass(/large-text/);
    await shot(page, "13-settings");
    await page.getByTestId("delete").click();
    await page.getByTestId("delete-confirm").click();
    await expect(page).toHaveURL(/\/intro\/$/);

    const page3 = await context.newPage();
    await page3.goto("/");
    await expect(page3).toHaveURL(/\/intro\/$/);
    await page3.close();
  });

  test("14-8 外部へのリクエストが一切ない", async () => {
    expect(externalRequests).toEqual([]);
  });
});

test.describe("アクセシビリティ（自動検査できる範囲）", () => {
  test("14-9 キーボードだけで導入→分身→部屋→プレビューを閉じるまで進める", async ({ page }) => {
    await page.goto("/intro/");
    const nickname = page.getByRole("textbox", { name: /ニックネーム/ });
    await expect(nickname).toBeVisible(); // 端末内データの読込後にフォームが出る
    await page.keyboard.press("Tab");
    await expect(nickname).toBeFocused();
    await page.keyboard.type("テスト");
    await page.keyboard.press("Tab");
    await expect(page.getByRole("button", { name: "はじめる" })).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(page).toHaveURL(/\/avatar\/$/);

    const done = page.getByRole("button", { name: "この姿にする" });
    for (let i = 0; i < 20; i += 1) {
      if (await done.evaluate((el) => el === document.activeElement)) break;
      await page.keyboard.press("Tab");
    }
    await expect(done).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(page).toHaveURL(/\/room\/$/);

    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();
    await expect(page.getByRole("heading", { name: "未来の部屋のプレビュー" })).toBeFocused();
    await page.keyboard.press("Tab");
    await expect(dialog.getByRole("button", { name: "自分の部屋へ" })).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(dialog).toBeHidden();
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("テストの鏡の部屋");
  });

  test("主要画面に見出しと役割付きの部屋画像がある", async ({ page }) => {
    await page.goto("/intro/");
    await page.getByRole("button", { name: "はじめる" }).click();
    await page.getByRole("button", { name: "この姿にする" }).click();
    await page.getByRole("button", { name: "自分の部屋へ" }).click();
    await expect(page.getByRole("img", { name: /鏡の部屋/ })).toBeVisible();
    for (const path of ["/plan/", "/log/", "/settings/", "/about/", "/avatar/"]) {
      await page.goto(path);
      await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    }
  });
});
