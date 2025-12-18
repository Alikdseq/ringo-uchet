## React Web фронт: деплой, UAT и cut‑over

Документ реализует шаг **W9.2** из `ReactWebFrontendPlan.md`:  
описывает, как деплоить новый React/Next.js фронт, как дать доступ пользователям для UAT и как безопасно переключиться с Flutter Web.

---

## 1. Артефакт фронта

- Исходники: каталог `frontend/` (Next.js 16, app router, React 19, TypeScript).
- Сборка:

```bash
cd frontend
npm install           # один раз
npm run build        # продовая сборка
```

- Продовый запуск (Node.js ≥ 20):

```bash
cd frontend
npm run start -- -p 3000    # или другой порт, например 3001 для staging
```

---

## 2. Staging окружение для фронта

### 2.1. Переменные окружения

- На staging‑сервере создать `.env.staging` в `frontend/`:

```bash
NEXT_PUBLIC_API_BASE_URL=https://api.ringo.stage/api/v1
NEXT_PUBLIC_ENV=staging
NEXT_PUBLIC_WEBPUSH_VAPID_PUBLIC_KEY=<VAPID_PUBLIC_KEY>   # если используем WebPush
```

### 2.2. Сервис фронта (systemd, пример)

```ini
[Unit]
Description=Ringo React Web (staging)
After=network.target

[Service]
Type=simple
WorkingDirectory=/srv/ringo/frontend
ExecStart=/usr/bin/npm run start -- -p 3001
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

После создания юнита:

```bash
sudo systemctl daemon-reload
sudo systemctl enable ringo-frontend-staging
sudo systemctl start ringo-frontend-staging
```

### 2.3. Nginx для staging

- Проксировать, например, `https://app.stage.ringoouchet.ru` → `http://127.0.0.1:3001`.
- Backend (`https://api.ringo.stage`) остаётся как в текущих backend‑гайдах.

---

## 3. UAT: доступ продвинутым пользователям

- После поднятия staging‑домена (`app.stage.ringoouchet.ru`) выдать ссылку ограниченному кругу пользователей.
- Что собирать:
  - UX: удобство форм (`/orders`, `/orders/create`, `/catalog/*`, `/profile/*`).
  - Скорость: субъективные ощущения + метрики Lighthouse (вкладка Chrome DevTools).
  - Стабильность: поведение при потере сети (`/offline-queue`, очередь синхронизации).
- Канал обратной связи: отдельный чат/форму, фиксировать конкретный URL, роль пользователя и шаг, на котором возникла проблема.

---

## 4. Cut‑over: переход с Flutter Web на новый React Web

### 4.1. Параллельный период

- Держать одновременно:
  - Текущий Flutter Web фронт (старый домен, условно `https://ringoouchet.ru`).
  - Новый React Web фронт (отдельный домен, например `https://app.ringoouchet.ru` или `/web2`).
- Синхронизация:
  - Backend общий, API уже адаптирован под оба фронта.
  - Следить за ошибками в логах backend и записывать расхождения в поведении (если React и Flutter по‑разному отображают одни и те же данные).

### 4.2. Переключение DNS/маршрутов

В момент cut‑over:

1. **Заморозить деплой Flutter Web** (больше не выкатывать изменения в старый фронт).
2. **Переключить домен**:
   - Вариант A: привязать `https://ringoouchet.ru` к новому React Web (Nginx upstream меняем на Node/Next).
   - Вариант B: редирект `https://ringoouchet.ru` → `https://app.ringoouchet.ru`, где уже крутится новый фронт.
3. После успешного cut‑over:
   - Оставить Flutter Web доступным только по скрытому URL или полностью выключить после короткого «grace‑period».
   - Продолжать мониторинг ошибок (Sentry/логи) и собирать обратную связь.

---

## 5. Итог

- Staging‑деплой React Web фронта описан и не конфликтует с существующим backend‑деплоем.
- UAT‑процесс и сбор обратной связи формализованы.
- План cut‑over позволяет безопасно переключиться со старого Flutter Web на новый React/Next.js фронт без даунтайма backend‑части.


