from __future__ import annotations

import uuid
from decimal import Decimal

from django.conf import settings
from django.db import models

from crm.models import Client


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания", help_text="Дата и время создания записи")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Дата обновления", help_text="Дата и время последнего обновления")

    class Meta:
        abstract = True


class OrderStatus(models.TextChoices):
    DRAFT = "DRAFT", "Черновик"
    CREATED = "CREATED", "Создан"
    APPROVED = "APPROVED", "Одобрен"
    IN_PROGRESS = "IN_PROGRESS", "В работе"
    COMPLETED = "COMPLETED", "Завершён"
    CANCELLED = "CANCELLED", "Отменён"
    DELETED = "DELETED", "Удалён"


class Order(TimeStampedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False, verbose_name="ID")
    number = models.CharField(max_length=32, unique=True, verbose_name="Номер заказа", help_text="Уникальный номер заказа")
    client = models.ForeignKey(
        Client,
        on_delete=models.SET_NULL,
        null=True,
        related_name="orders",
        verbose_name="Клиент",
        help_text="Клиент, для которого выполняется заказ",
    )
    address = models.CharField(max_length=500, verbose_name="Адрес", help_text="Адрес выполнения работ")
    geo_lat = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True, verbose_name="Широта", help_text="Географическая широта"
    )
    geo_lng = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True, verbose_name="Долгота", help_text="Географическая долгота"
    )
    start_dt = models.DateTimeField(verbose_name="Дата начала", help_text="Дата и время начала работ")
    end_dt = models.DateTimeField(null=True, blank=True, verbose_name="Дата окончания", help_text="Дата и время окончания работ")
    description = models.TextField(blank=True, verbose_name="Описание", help_text="Подробное описание заказа")
    status = models.CharField(
        max_length=20,
        choices=OrderStatus.choices,
        default=OrderStatus.CREATED,
        verbose_name="Статус",
        help_text="Текущий статус заказа",
    )
    manager = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="managed_orders",
        verbose_name="Менеджер",
        help_text="Менеджер, ответственный за заказ",
    )
    operators = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        related_name="operated_orders",
        blank=True,
        verbose_name="Операторы",
        help_text="Операторы, выполняющие заказ",
    )
    # Оставляем operator для обратной совместимости (deprecated)
    operator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="operated_orders_legacy",
        verbose_name="Оператор (устаревшее)",
        help_text="Оператор, выполняющий заказ (устаревшее поле, используйте operators)",
    )
    prepayment_amount = models.DecimalField(
        max_digits=12, decimal_places=2, default=Decimal("0.00"), verbose_name="Сумма предоплаты", help_text="Сумма предоплаты"
    )
    prepayment_status = models.CharField(
        max_length=20, default="pending", verbose_name="Статус предоплаты", help_text="Статус предоплаты"
    )
    total_amount = models.DecimalField(
        max_digits=12, decimal_places=2, default=Decimal("0.00"), verbose_name="Общая сумма", help_text="Общая сумма заказа"
    )
    price_snapshot = models.JSONField(
        default=dict, blank=True, verbose_name="Снимок расчёта", help_text="JSON снимок расчёта стоимости"
    )
    attachments = models.JSONField(
        default=list, blank=True, verbose_name="Вложения", help_text="Список вложенных файлов"
    )
    meta = models.JSONField(default=dict, blank=True, verbose_name="Метаданные", help_text="Дополнительные метаданные")
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="orders_created",
        verbose_name="Создал",
        help_text="Пользователь, создавший заказ",
    )

    class Meta:
        verbose_name = "Заказ"
        verbose_name_plural = "Заказы"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status"]),
            models.Index(fields=["start_dt"]),
        ]

    def __str__(self) -> str:
        return f"Заказ {self.number}"


class OrderItem(TimeStampedModel):
    class ItemType(models.TextChoices):
        EQUIPMENT = "equipment", "Техника"
        SERVICE = "service", "Услуга"
        MATERIAL = "material", "Материал"
        ATTACHMENT = "attachment", "Навеска"

    order = models.ForeignKey(
        Order, on_delete=models.CASCADE, related_name="items", verbose_name="Заказ", help_text="Заказ, к которому относится позиция"
    )
    item_type = models.CharField(
        max_length=20, choices=ItemType.choices, verbose_name="Тип позиции", help_text="Тип позиции заказа"
    )
    ref_id = models.PositiveIntegerField(
        null=True, blank=True, verbose_name="ID в исходной таблице", help_text="ID элемента в исходной таблице"
    )
    name_snapshot = models.CharField(max_length=255, verbose_name="Название", help_text="Название позиции")
    quantity = models.DecimalField(
        max_digits=10, decimal_places=2, default=Decimal("1.00"), verbose_name="Количество", help_text="Количество единиц"
    )
    unit = models.CharField(max_length=32, blank=True, verbose_name="Единица измерения", help_text="Единица измерения (час, день, шт.)")
    unit_price = models.DecimalField(
        max_digits=12, decimal_places=2, verbose_name="Цена за единицу", help_text="Цена за единицу измерения"
    )
    tax_rate = models.DecimalField(
        max_digits=5, decimal_places=2, default=Decimal("0.00"), verbose_name="Налоговая ставка", help_text="Налоговая ставка в процентах"
    )
    discount = models.DecimalField(
        max_digits=6, decimal_places=2, default=Decimal("0.00"), verbose_name="Скидка", help_text="Скидка в процентах"
    )
    fuel_expense = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        default=None,
        verbose_name="Расходы на топливо",
        help_text="Расходы на топливо для данной техники",
    )
    repair_expense = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        default=None,
        verbose_name="Расходы на ремонт техники",
        help_text="Расходы на ремонт техники",
    )
    metadata = models.JSONField(default=dict, blank=True, verbose_name="Метаданные", help_text="Дополнительные метаданные")

    class Meta:
        verbose_name = "Позиция заказа"
        verbose_name_plural = "Позиции заказов"

    def __str__(self) -> str:
        return f"{self.name_snapshot} x{self.quantity}"


class OrderStatusLog(models.Model):
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name="status_logs",
        verbose_name="Заказ",
        help_text="Заказ, для которого изменён статус",
    )
    from_status = models.CharField(
        max_length=20, choices=OrderStatus.choices, blank=True, verbose_name="Старый статус", help_text="Предыдущий статус"
    )
    to_status = models.CharField(
        max_length=20, choices=OrderStatus.choices, verbose_name="Новый статус", help_text="Новый статус заказа"
    )
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="order_status_logs",
        verbose_name="Исполнитель",
        help_text="Пользователь, изменивший статус",
    )
    comment = models.TextField(blank=True, verbose_name="Комментарий", help_text="Комментарий к изменению статуса")
    attachment_url = models.URLField(blank=True, verbose_name="URL вложения", help_text="URL прикреплённого файла")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания", help_text="Дата и время изменения статуса")

    class Meta:
        verbose_name = "Лог изменения статуса"
        verbose_name_plural = "Логи изменений статусов"
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"{self.order.number}: {self.get_from_status_display()} → {self.get_to_status_display()}"


class PhotoEvidence(TimeStampedModel):
    class PhotoType(models.TextChoices):
        BEFORE = "before", "До работ"
        AFTER = "after", "После работ"
        INCIDENT = "incident", "Инцидент"

    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name="photos",
        verbose_name="Заказ",
        help_text="Заказ, к которому относится фото",
    )
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="photo_evidence",
        verbose_name="Загрузил",
        help_text="Пользователь, загрузивший фото",
    )
    photo_type = models.CharField(
        max_length=20,
        choices=PhotoType.choices,
        default=PhotoType.BEFORE,
        verbose_name="Тип фото",
        help_text="Тип фотографии",
    )
    file_url = models.URLField(verbose_name="URL файла", help_text="URL фотографии")
    gps_lat = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True, verbose_name="Широта GPS", help_text="Широта места съёмки"
    )
    gps_lng = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True, verbose_name="Долгота GPS", help_text="Долгота места съёмки"
    )
    captured_at = models.DateTimeField(null=True, blank=True, verbose_name="Дата съёмки", help_text="Дата и время съёмки")
    notes = models.TextField(blank=True, verbose_name="Примечания", help_text="Дополнительные примечания к фото")
    metadata = models.JSONField(default=dict, blank=True, verbose_name="Метаданные", help_text="Дополнительные метаданные")

    class Meta:
        verbose_name = "Фото-доказательство"
        verbose_name_plural = "Фото-доказательства"

    def __str__(self) -> str:
        return f"{self.order.number} фото ({self.get_photo_type_display()})"

