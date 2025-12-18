## Ringo Uchet — React/Next.js frontend

Новый веб‑фронт для системы учёта Ringo, переписанный с Flutter Web на **Next.js + React + TypeScript**, с полной адаптацией под мобильные устройства.

---

## Архитектура

- **Next.js App Router** (`src/app`).
- **React 19 + TypeScript**.
- **Состояние / данные**:
  - `@tanstack/react-query` — серверное состояние и кэш запросов.
  - `zustand` — auth‑состояние и пользователь.
- **HTTP**:
  - `axios` с общим клиентом `httpClient` (`src/shared/api/httpClient.ts`), JWT через `Authorization: Bearer`.
- **UI**:
  - Tailwind CSS 4 + лёгкие headless‑компоненты (`Card`, `PageHeader`, `DataTable`, `StatusBadge`).
  - Адаптивная навигация: `AppShell` с `SideNav` (desktop) и `BottomNav` (mobile).
- **Доменные слои**:
  - `src/shared/api/*` — обёртки над backend‑эндпоинтами (auth, orders, catalog, reports, notifications, profile).
  - `src/shared/types/*` — модели/маппинги JSON → TS (orders, catalog, auth, reports, salary).
  - `src/shared/offline/offlineQueue.ts` — оффлайн‑очередь запросов (создание/статусы/завершение заявок).

Подробнее по маршрутам и API см. `ReactWeb_Routes.md` и `ReactWeb_Inventory.md`.

---

## Команды

```bash
cd frontend

# разработка
npm run dev

# линт и типы
npm run lint
npm run typecheck

# юнит/компонентные тесты (Vitest)
npm run test

# E2E (Playwright)
npm run test:e2e

# продовая сборка и запуск
npm run build
npm run start
```

---

## Структура каталогов

- `src/app` — маршруты и страницы Next.js (App Router).
  - `(auth)` — login/register.
  - `(app)` — основное приложение: `orders`, `catalog`, `reports`, `profile`, `offline-queue` и т.д.
- `src/shared/api` — HTTP‑клиент и сервисы (`authApi`, `ordersApi`, `catalogApi`, `reportsApi`, `notificationsApi`, `profileApi`).
- `src/shared/types` — доменные типы и функции маппинга (`orders`, `catalog`, `auth`, `reports`, `salary`).
- `src/shared/components` — переиспользуемые компоненты (layout, ui, providers, auth‑guards).
- `src/shared/store` — Zustand‑хранилища (`authStore`).
- `src/shared/offline` — оффлайн‑очередь запросов.
- `tests` — Vitest unit/components + Playwright e2e.

---

## Мониторинг и Web Vitals

- Service worker (`public/webpush-sw.js`):
  - кеширует статику и часть API;
  - обрабатывает Web Push‑уведомления.
- Для подключения Sentry и отправки Web Vitals можно следовать рекомендациям в `ReactWeb_DEPLOY.md` (секция мониторинга) — DSN и окружения задаются через переменные `NEXT_PUBLIC_SENTRY_DSN` и аналогичные.
