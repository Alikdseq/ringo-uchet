import { expect, test } from "@playwright/test";

test.describe("Основной пользовательский сценарий", () => {
  test("логин → переход в заявки", async ({ page }) => {
    await page.goto("/");
    // В реальном окружении здесь будет редирект на /login для неавторизованных
    // Пока просто проверяем, что дашборд отвечает.
    await expect(page.locator("text=Dashboard")).toBeVisible();
  });
});


