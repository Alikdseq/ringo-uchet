## ERD — Ringo Uchet

### Основные сущности

| Сущность            | Ключевые поля                                                                                                      | Связи                                                                                                 |
|---------------------|---------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| `User`              | `id (UUID)`, `phone`, `email`, `role`, `first_name`, `last_name`, `is_active`, `locale`, `avatar_url`               | `managed_orders`, `operated_orders`, `notifications`, `salary_records`, `audit_logs`                  |
| `Role`/Permissions  | `name`, `description`, `permissions JSON snapshot`                                                                 | Many-to-many с `User`                                                                                 |
| `Equipment`         | `id`, `code`, `name`, `hourly_rate`, `daily_rate`, `fuel_consumption`, `status`, `photos`, `last_maintenance_date` | `order_items`, `expenses`, `maintenance_records`                                                      |
| `ServiceCategory`   | `id`, `name`, `description`                                                                                        | `service_items`                                                                                       |
| `ServiceItem`       | `id`, `category`, `name`, `unit`, `price`, `default_duration`, `included_items JSON`                               | `order_items`                                                                                         |
| `MaterialItem`      | `id`, `name`, `unit`, `price`, `density`, `supplier`                                                               | `order_items`, `expenses`                                                                             |
| `Attachment/Tool`   | `id`, `equipment`, `name`, `pricing_modifier`, `status`                                                            | `order_items`                                                                                         |
| `Client`            | `id`, `name`, `phone`, `email`, `billing_details JSON`, `address`, `city`, `inn`, `kpp`                            | `orders`, `invoices`                                                                                  |
| `Order`             | `uuid`, `number`, `client`, `address`, `geo`, `start_dt`, `end_dt`, `status`, `manager`, `operator`, `price_snapshot`, `total_amount`, `prepayment_amount`, `prepayment_status`, `notes` | `order_items`, `status_logs`, `photo_evidence`, `invoices`, `expenses`, `payments`, `audit_logs`     |
| `OrderItem`         | `id`, `order`, `item_type`, `ref_id`, `name_snapshot`, `quantity`, `unit_price`, `tax_rate`, `discount`, `metadata`| FK → `Order`                                                                                           |
| `OrderStatusLog`    | `id`, `order`, `from_status`, `to_status`, `actor`, `comment`, `attachment`, `created_at`                          | FK → `Order`, `User`                                                                                  |
| `PhotoEvidence`     | `id`, `order`, `type (before/after)`, `file_url`, `gps_lat`, `gps_lng`, `captured_at`, `operator`, `notes`         | FK → `Order`, `User`                                                                                  |
| `Invoice`           | `id`, `order`, `number`, `pdf_url`, `payment_status`, `sent_at`, `due_date`, `currency`                            | FK → `Order`, `Payment`                                                                               |
| `Expense`           | `id`, `order?`, `equipment?`, `user?`, `category`, `amount`, `date`, `comment`, `attachment`                       | Optional FK → `Order`, `Equipment`, `User`                                                            |
| `SalaryRecord`      | `id`, `user`, `order`, `hours_worked`, `rate_type`, `amount`, `status`, `paid_at`                                  | FK → `User`, `Order`                                                                                  |
| `Payment`           | `id`, `order`, `invoice`, `method`, `provider_ref`, `status`, `amount`, `paid_at`, `currency`, `metadata`          | FK → `Order`, `Invoice`                                                                               |
| `NotificationPreference` | `id`, `user`, `channel (push/email/sms/telegram)`, `enabled`, `topics JSON`                                  | FK → `User`                                                                                           |
| `DeviceToken`       | `id`, `user`, `platform`, `token`, `last_seen_at`, `locale`                                                        | FK → `User`                                                                                           |
| `AuditLog`          | `id`, `actor`, `entity_type`, `entity_id`, `action`, `payload JSON`, `ip`, `user_agent`, `created_at`              | FK → `User` (nullable)                                                                                |

### Связи (диаграмма-пояснение)

```
User 1 --- * Order (manager/operator)
Order 1 --- * OrderItem
Order 1 --- * OrderStatusLog
Order 1 --- * PhotoEvidence
Order 1 --- 1 Invoice --- * Payment
Order 1 --- * Expense
Order 1 --- * SalaryRecord --- 1 User
Equipment 1 --- * OrderItem (item_type=equipment)
ServiceItem 1 --- * OrderItem (item_type=service)
MaterialItem 1 --- * OrderItem (item_type=material)
Client 1 --- * Order
User 1 --- * AuditLog
```

Полная ERD диаграмма будет поддерживаться в `docs/erd/ringo-erd.drawio` (экспорт в PNG/PDF при апдейтах). Текущая таблица фиксирует сущности/поля для синхронизации всей команды.

