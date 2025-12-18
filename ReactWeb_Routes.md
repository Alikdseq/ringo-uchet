## 🧭 Карта маршрутов нового React/Next.js веб‑приложения Ringo Uchet

Документ реализует шаг **W0.2** из `ReactWebFrontendPlan.md`:  
спроектирована структура URL и страниц (Next.js `app` router) и увязана с текущими Flutter‑экранами и backend API.

---

## 1. Общая структура роутинга и layout‑групп

Используем **Next.js 14+ App Router** с группами:

- `src/app/(auth)/...` — страницы авторизации (неавторизованный доступ).
- `src/app/(app)/...` — основное приложение (требует авторизации).

Базовые layout’ы:

- `src/app/layout.tsx` — корневой layout (тема, провайдеры, глобальные стили).
- `src/app/(auth)/layout.tsx` — упрощённый layout форм логина/регистрации.
- `src/app/(app)/layout.tsx` — основной `AppLayout` с AppBar/SideNav/BottomNav.

Глобальная навигация (по ролям) внутри `(app)`:

- **admin**: Dashboard, Orders, Catalog, Reports, Profile, Offline Queue.
- **manager**: Dashboard, Orders, Catalog, (часть Reports), Profile, Offline Queue.
- **operator**: Dashboard, Orders (только свои), Salary, Profile, Offline Queue.

---

## 2. Детальная карта маршрутов

### 2.1 Auth‑группа `(auth)`

#### `/login`
- **Next.js**: `src/app/(auth)/login/page.tsx`
- **Flutter аналог**: `LoginScreen`.
- **Назначение**: вход по телефону/email/username и паролю, обработка ошибок, редирект в приложение.
- **Доступ**: аноним; при наличии auth → редирект на `/`.
- **API**:
  - `POST /token/` — логин.
  - `POST /auth/otp/send/` / `POST /auth/otp/verify/` — опционально (если будет активен OTP‑flow).
  - `GET /users/me/` — проверка сессии после логина (через `AuthApi.getCurrentUser`).

#### `/register`
- **Next.js**: `src/app/(auth)/register/page.tsx`
- **Flutter аналог**: `RegisterScreen`.
- **Назначение**: регистрация нового пользователя (оператора) с последующим авто‑логином.
- **Доступ**: аноним.
- **API**:
  - `POST /users/register/`
  - `POST /token/`
  - `GET /users/me/`

#### `/forgot-password` (опционально)
- **Next.js**: `src/app/(auth)/forgot-password/page.tsx`
- **Flutter аналог**: сейчас отсутствует (можно реализовать позже).
- **Назначение**: восстановление пароля (если будет реализовано на backend).
- **API**: TBD (пока только зарезервирован маршрут).

---

### 2.2 Главный экран и навигация `(app)`

#### `/` — Dashboard
- **Next.js**: `src/app/(app)/page.tsx`
- **Flutter аналог**: `DashboardScreen`.
- **Назначение**:
  - Показ KPI карточек (новые/назначенные заявки, доход).
  - Мини‑графики активности за период.
  - Быстрые действия (создание заявки, переход к отчётам).
- **Доступ**: авторизованные пользователи; содержимое зависит от роли.
- **API**:
  - `GET /orders/` — для расчёта KPI и графиков (с кэшем).
  - (опционально) `GET /reports/summary/` — для агрегации показателей.

---

### 2.3 Заявки (Orders)

#### `/orders`
- **Next.js**: `src/app/(app)/orders/page.tsx`
- **Flutter аналог**: `OrdersListScreen`.
- **Назначение**:
  - Список заявок с табами по статусам, поиском, пагинацией.
  - Интеграция с оффлайн‑баннером и индикатором очереди.
- **Доступ**:
  - `admin/manager`: все заявки.
  - `operator`: только свои (фронт фильтрует по `operatorId`/`operator`).
- **API**:
  - `GET /orders/` (параметры `status`, `search`, `page`, `page_size`).

#### `/orders/create`
- **Next.js**: `src/app/(app)/orders/create/page.tsx`
- **Flutter аналог**: `CreateOrderScreen`.
- **Назначение**:
  - Мастер создания заявки (клиент → адрес → номенклатура → даты → предпросмотр цены).
  - Возможность сохранения черновиков.
- **Доступ**: `admin/manager` (по умолчанию; операторы могут создавать заявки по бизнес‑правилам).
- **API**:
  - `GET /clients/` + `POST /clients/` — выбор/создание клиента.
  - `GET /equipment/`, `/services/`, `/materials/`, `/attachments/` — выбор номенклатуры.
  - `GET /users/operators/` — выбор операторов.
  - `POST /orders/` — создание заявки/черновика.
  - `POST /orders/{id}/calculate/preview/` — предпросмотр цены (если используется связка с уже созданным заказом) или локальный расчёт.

#### `/orders/[orderId]`
- **Next.js**: `src/app/(app)/orders/[orderId]/page.tsx`
- **Flutter аналог**: `OrderDetailScreen`.
- **Назначение**:
  - Просмотр полной информации по заявке.
  - Смена статуса, просмотр таймлайна, фото, финансов, операторов.
  - Переход к редактированию и завершению.
- **Доступ**:
  - `admin/manager`: свои/все заявки по политике доступа.
  - `operator`: только заявки, где он назначен (проверка роли и сущности).
- **API**:
  - `GET /orders/{id}/`
  - `PATCH /orders/{id}/status/`
  - `POST /orders/{id}/generate_invoice/`
  - `GET /orders/{id}/receipt/`
  - `POST /orders/{id}/delete/`

#### `/orders/[orderId]/edit`
- **Next.js**: `src/app/(app)/orders/[orderId]/edit/page.tsx`
- **Flutter аналог**: `OrderEditScreen`.
- **Назначение**:
  - Полное редактирование заявки (номенклатура, операторы, стоимость и др.).
- **Доступ**: в основном `admin/manager`.
- **API**:
  - `GET /orders/{id}/`
  - `GET /equipment/`, `/services/`, `/materials/`, `/attachments/`
  - `GET /users/operators/`
  - `PATCH /orders/{id}/`
  - `POST /orders/{id}/calculate/preview/`

#### `/orders/[orderId]/complete`
- **Next.js**: `src/app/(app)/orders/[orderId]/complete/page.tsx`
- **Flutter аналог**: `CompleteOrderScreen`.
- **Назначение**:
  - Завершение заявки с вводом фактических смен/часов/расходов.
  - Формирование payload для `/orders/{id}/complete/`.
- **Доступ**: `admin/manager` (по бизнес‑правилам; оператор может предлагать значения).
- **API**:
  - `GET /orders/{id}/`
  - `POST /orders/{id}/complete/`
  - (косвенно) `POST /orders/{id}/status/` (если смена статуса завершается здесь).

---

### 2.4 Каталог (Catalog)

Блок каталогов можно сгруппировать под общим layout `src/app/(app)/catalog/layout.tsx` с навигацией по вкладкам.

#### `/catalog/equipment`
- **Next.js**: `src/app/(app)/catalog/equipment/page.tsx`
- **Flutter аналог**: CatalogScreen — вкладка «Техника».
- **Назначение**:
  - Список техники с фильтрами и статусами.
  - Для admin — действия создания/редактирования/удаления.
- **API**:
  - `GET /equipment/`
  - CRUD эндпоинты (если используются во фронте).

#### `/catalog/services`
- **Next.js**: `src/app/(app)/catalog/services/page.tsx`
- **Flutter аналог**: CatalogScreen — вкладка «Услуги».
- **API**:
  - `GET /services/`
  - CRUD по услугам.

#### `/catalog/materials`
- **Next.js**: `src/app/(app)/catalog/materials/page.tsx`
- **Flutter аналог**: CatalogScreen — вкладка «Материалы/грунт`.
- **API**:
  - `GET /materials/`
  - CRUD по материалам.

#### `/catalog/attachments`
- **Next.js**: `src/app/(app)/catalog/attachments/page.tsx`
- **Flutter аналог**: CatalogScreen — вкладка «Навеска» (Attachment).
- **API**:
  - `GET /attachments/`
  - CRUD по навескам.

#### `/catalog/clients`
- **Next.js**: `src/app/(app)/catalog/clients/page.tsx`
- **Flutter аналог**: часть CatalogScreen + создание клиентов в CreateOrderScreen.
- **API**:
  - `GET /clients/`
  - `POST /clients/`
  - (по необходимости) PATCH/DELETE для админ‑управления клиентами.

---

### 2.5 Отчёты (Reports)

#### `/reports/summary`
- **Next.js**: `src/app/(app)/reports/summary/page.tsx`
- **Flutter аналог**: ReportsScreen — вкладка общих отчётов.
- **API**:
  - `GET /reports/summary/` (с фильтром по периоду через query‑параметры или состояние).

#### `/reports/equipment`
- **Next.js**: `src/app/(app)/reports/equipment/page.tsx`
- **Flutter аналог**: ReportsScreen — вкладка по технике.
- **API**:
  - `GET /reports/equipment/`

#### `/reports/employees`
- **Next.js**: `src/app/(app)/reports/employees/page.tsx`
- **Flutter аналог**: ReportsScreen — вкладка по сотрудникам.
- **API**:
  - `GET /reports/employees/`

---

### 2.6 Профиль и связанные разделы

#### `/profile`
- **Next.js**: `src/app/(app)/profile/page.tsx`
- **Flutter аналог**: `ProfileScreen` (основной).
- **Назначение**:
  - Отображение карточки пользователя.
  - Навигация к смене пароля, настройкам уведомлений, оффлайн‑очереди.
- **API**:
  - `GET /users/me/`
  - `POST /token/blacklist/` (logout).

#### `/profile/password`
- **Next.js**: `src/app/(app)/profile/password/page.tsx`
- **Flutter аналог**: `ChangePasswordScreen`.
- **API**:
  - `POST /users/change-password/`

#### `/profile/notifications`
- **Next.js**: `src/app/(app)/profile/notifications/page.tsx`
- **Flutter аналог**: `NotificationSettingsScreen`.
- **API**:
  - `GET /notifications/preferences/preferences/`
  - `POST /notifications/preferences/preferences/`
  - (опционально) `GET /notifications/preferences/logs/`

#### `/profile/salary`
- **Next.js**: `src/app/(app)/profile/salary/page.tsx`
- **Flutter аналог**: `OperatorSalaryScreen`.
- **Назначение**:
  - Доступен только для `role=operator`.
  - Показ начислений и заказов с фильтром по периоду.
- **API**:
  - `GET /users/operator/salary/`

---

### 2.7 Оффлайн‑очередь

#### `/offline-queue`
- **Next.js**: `src/app/(app)/offline-queue/page.tsx`
- **Flutter аналог**: `OfflineQueueScreen`.
- **Назначение**:
  - Просмотр локально сохранённой очереди действий (создание/редактирование/смена статуса).
  - Ручной retry/удаление элементов.
- **API (косвенно)**:
  - При ретрае — те же эндпоинты, что и для Orders (через фронтовый `OfflineQueueService`).

---

## 3. Соответствие маршрутов Flutter‑экранам (сводная таблица)

| Next.js маршрут                            | Next компонент                                | Flutter экран              | Основные API                                      |
|-------------------------------------------|-----------------------------------------------|----------------------------|---------------------------------------------------|
| `/login`                                  | `(auth)/login/page.tsx`                       | `LoginScreen`              | `/token/`, `/users/me/`                          |
| `/register`                               | `(auth)/register/page.tsx`                    | `RegisterScreen`           | `/users/register/`, `/token/`, `/users/me/`     |
| `/`                                       | `(app)/page.tsx`                              | `DashboardScreen`          | `/orders/`, `/reports/summary/` (опц.)          |
| `/orders`                                 | `(app)/orders/page.tsx`                       | `OrdersListScreen`         | `/orders/`                                       |
| `/orders/create`                          | `(app)/orders/create/page.tsx`                | `CreateOrderScreen`        | `/orders/`, `/clients/`, `/equipment/`…         |
| `/orders/[orderId]`                       | `(app)/orders/[orderId]/page.tsx`             | `OrderDetailScreen`        | `/orders/{id}/`, `/orders/{id}/status/`…        |
| `/orders/[orderId]/edit`                  | `(app)/orders/[orderId]/edit/page.tsx`        | `OrderEditScreen`          | `/orders/{id}/`, `/orders/{id}/calculate/preview/` |
| `/orders/[orderId]/complete`              | `(app)/orders/[orderId]/complete/page.tsx`    | `CompleteOrderScreen`      | `/orders/{id}/complete/`, `/orders/{id}/status/`|
| `/catalog/equipment`                      | `(app)/catalog/equipment/page.tsx`            | CatalogScreen (equipment)  | `/equipment/`                                    |
| `/catalog/services`                       | `(app)/catalog/services/page.tsx`             | CatalogScreen (services)   | `/services/`                                     |
| `/catalog/materials`                      | `(app)/catalog/materials/page.tsx`            | CatalogScreen (materials)  | `/materials/`                                    |
| `/catalog/attachments`                    | `(app)/catalog/attachments/page.tsx`          | CatalogScreen (attachments)| `/attachments/`                                  |
| `/catalog/clients`                        | `(app)/catalog/clients/page.tsx`              | CatalogScreen + dialogs    | `/clients/`                                      |
| `/reports/summary`                        | `(app)/reports/summary/page.tsx`              | ReportsScreen (summary)    | `/reports/summary/`                              |
| `/reports/equipment`                      | `(app)/reports/equipment/page.tsx`            | ReportsScreen (equipment)  | `/reports/equipment/`                            |
| `/reports/employees`                      | `(app)/reports/employees/page.tsx`            | ReportsScreen (employees)  | `/reports/employees/`                            |
| `/profile`                                | `(app)/profile/page.tsx`                      | `ProfileScreen`            | `/users/me/`, `/token/blacklist/`               |
| `/profile/password`                       | `(app)/profile/password/page.tsx`             | `ChangePasswordScreen`     | `/users/change-password/`                        |
| `/profile/notifications`                  | `(app)/profile/notifications/page.tsx`        | `NotificationSettingsScreen`| `/notifications/preferences/preferences/`       |
| `/profile/salary`                         | `(app)/profile/salary/page.tsx`               | `OperatorSalaryScreen`     | `/users/operator/salary/`                        |
| `/offline-queue`                          | `(app)/offline-queue/page.tsx`                | `OfflineQueueScreen`       | (косвенно) `/orders/...` через оффлайн‑очередь   |

Маршрутная карта покрывает все ключевые сценарии текущего Flutter‑клиента и служит основой для реализации Next.js‑роутинга без потери функциональности.


